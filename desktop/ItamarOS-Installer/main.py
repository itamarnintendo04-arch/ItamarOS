"""ItamarOS Installer — desktop application for Windows."""
from __future__ import annotations

import os
import plistlib
import zipfile
import queue
import sys
import threading
import webbrowser
from pathlib import Path
from tkinter import messagebox, filedialog, simpledialog
from PIL import Image
import urllib.parse
import urllib.request

import customtkinter as ctk
from lan_bridge import CompanionServer, InstallRequest, local_ipv4
from desktop_certificates import DesktopCertificates
from driver_setup import check_drivers, install_apple_devices, open_official_store
from certificate_archives import extract_archives
from official_catalog import OfficialCatalog
import qrcode
from store_sources import CommunitySources
from store_ui import StoreUIMixin

from installer_core import (
    GitHubCatalog, CatalogApp, InstallerError, DOWNLOAD_DIR,
    command_for_device_tool, friendly_error, install_ipa,
    mobile_device_service_running, download_ipa, scan_devices,
)

ctk.set_appearance_mode("dark")
ctk.set_default_color_theme("blue")
BG, PANEL, INNER = "#080f19", "#101c2a", "#142536"
TEAL, HOVER, WHITE, MUTED = "#25e0c0", "#137e73", "#e9f7fa", "#92aab9"
BORDER = "#213c4d"


class Installer(StoreUIMixin, ctk.CTk):
    def __init__(self):
        super().__init__(fg_color=BG)
        self.title("ItamarOS Installer")
        self.geometry("1180x750")
        self.minsize(980, 640)
        self.protocol("WM_DELETE_WINDOW", self._close)
        self.events = queue.Queue()
        self.apps: list[CatalogApp] = []
        self.devices: list[dict[str, str]] = []
        self.selected_udid = ""
        self.busy = False
        self.catalog = GitHubCatalog()
        self.official = OfficialCatalog()
        self.desktop_certificates = DesktopCertificates()
        self.store_sources = CommunitySources(self.official)
        self.store_rows = []
        self.store_section = "Discover"
        self.store_search_var = ctk.StringVar()
        self.store_search_var.trace_add(
            "write", lambda *_: self._render_store_cards()
            if hasattr(self, "store_cards") else None)
        self.lan_server: CompanionServer | None = None
        self.lan_image = None
        self.lan_status_text = None
        self.category_filter = "All"
        self._app_images = {}
        self._image_fetching = set()
        self.search_text = ctk.StringVar()
        self.device_choice = ctk.StringVar(value="No iPhone selected")
        self._init_shell()
        self.after(100, self._handle_events)
        self.after(180, self._refresh_store)
        self.after(2500, self.scan_device)
        self.after(1_200_000, self._periodic_refresh)

    def _init_shell(self):
        self.grid_columnconfigure(1, weight=1)
        self.grid_rowconfigure(0, weight=1)
        side = ctk.CTkFrame(self, width=248, corner_radius=0, fg_color="#0d1824")
        side.grid(row=0, column=0, sticky="nsew")
        side.grid_propagate(False)
        logo = ctk.CTkFrame(side, height=68, fg_color="transparent")
        logo.pack(fill="x", padx=20, pady=(24, 28))
        brand_icon = self._load_resource("brand", (54, 54))
        if brand_icon:
            ctk.CTkLabel(logo, text="", image=brand_icon, width=56, height=56).pack(side="left")
        else:
            ctk.CTkLabel(logo, text="◈", font=("Segoe UI", 31, "bold"), text_color=TEAL).pack(side="left")
        ctk.CTkLabel(logo, text="ItamarOS\nInstaller", font=("Segoe UI", 20, "bold"),
                     text_color=WHITE, justify="left").pack(side="left", padx=12)
        self._nav(side, "✦  Discover", lambda: self.show_store("Discover"))
        self._nav(side, "▦  Apps", lambda: self.show_store("Apps"))
        self._nav(side, "◈  Games", lambda: self.show_store("Games"))
        self._nav(side, "↻  Updates", lambda: self.show_store("Updates"))
        self._nav(side, "▣  Library", lambda: self.show_store("Library"))
        self._nav(side, "⊞  Sources", lambda: self.show_store("Sources"))
        self._nav(side, "▦  App Catalog", self.show_catalog)
        self._nav(side, "◉  My iPhone", self.show_device)
        self._nav(side, "↓  Install Drivers", self.show_driver_setup)
        self._nav(side, "⌁  Wi-Fi Companion", self.show_wifi_companion)
        self._nav(side, "♢  Signing Certificates", self.show_certificates)
        self._nav(side, "⇣  Downloads", self.open_downloads)
        ctk.CTkFrame(side, fg_color=BORDER, height=1).pack(fill="x", padx=23, pady=22)
        ctk.CTkLabel(side, text="APPLE ACCOUNT", font=("Segoe UI", 11, "bold"),
                     text_color=MUTED, anchor="w").pack(fill="x", padx=24)
        ctk.CTkLabel(side, text="Not connected", text_color=WHITE,
                     font=("Segoe UI", 13), anchor="w").pack(fill="x", padx=24, pady=(6, 4))
        ctk.CTkButton(side, text="Sign in with Apple", command=self.apple_login,
                      corner_radius=10, height=38, fg_color="#263749", hover_color="#314b60",
                      font=("Segoe UI", 13, "bold")).pack(fill="x", padx=20, pady=8)
        ctk.CTkLabel(side, text="Apple sign-in uses a browser,\nnever a password field here.",
                     justify="left", font=("Segoe UI", 11), text_color=MUTED).pack(anchor="w", padx=24)
        ctk.CTkLabel(side, text="ItamarOS Installer v2.3\nWindows 10 / 11",
                     text_color="#7892a1", font=("Segoe UI", 11), justify="left").pack(
                         side="bottom", anchor="w", padx=24, pady=24)

        self.main = ctk.CTkFrame(self, fg_color=BG, corner_radius=0)
        self.main.grid(row=0, column=1, sticky="nsew")
        self.main.grid_columnconfigure(0, weight=1)
        self.main.grid_rowconfigure(1, weight=1)
        header = ctk.CTkFrame(self.main, fg_color="transparent")
        header.grid(row=0, column=0, sticky="ew", padx=30, pady=(27, 16))
        ctk.CTkLabel(header, text="Your iPhone. Your apps.", text_color=WHITE,
                     font=("Segoe UI", 25, "bold")).pack(side="left")
        self.refresh_button = ctk.CTkButton(
            header, text="↻ Refresh Catalog", font=("Segoe UI", 13, "bold"),
            fg_color="#233849", hover_color="#365267", width=158, height=36,
            command=lambda: self.refresh_catalog(force=True))
        self.refresh_button.pack(side="right")
        self.content = ctk.CTkScrollableFrame(self.main, fg_color="transparent")
        self.content.grid(row=1, column=0, sticky="nsew", padx=(25, 8), pady=(0, 14))
        self.content.grid_columnconfigure(0, weight=1)
        bottom = ctk.CTkFrame(self.main, height=54, corner_radius=0, fg_color="#101d29")
        bottom.grid(row=2, column=0, sticky="ew")
        self.status = ctk.CTkLabel(bottom, text="Connecting to the ItamarOS catalog...",
                                   text_color=MUTED, font=("Segoe UI", 12))
        self.status.pack(side="left", padx=25)
        self.progress = ctk.CTkProgressBar(bottom, width=170, height=8,
                                          fg_color="#203744", progress_color=TEAL)
        self.progress.set(0)
        self.progress.pack(side="right", padx=25)
        self.show_store("Discover")

    def _nav(self, sidebar, text, callback):
        ctk.CTkButton(sidebar, text=text, command=callback, anchor="w",
                      height=44, fg_color="transparent", hover_color="#203747",
                      text_color=WHITE, font=("Segoe UI", 14),
                      corner_radius=10).pack(fill="x", padx=12, pady=3)

    def _clear(self):
        for child in self.content.winfo_children():
            child.destroy()

    def _section(self, text, subtitle=None):
        block = ctk.CTkFrame(self.content, fg_color="transparent")
        block.pack(fill="x", padx=7, pady=(8, 10))
        ctk.CTkLabel(block, text=text, font=("Segoe UI", 22, "bold"),
                     text_color=WHITE).pack(anchor="w")
        if subtitle:
            ctk.CTkLabel(block, text=subtitle, font=("Segoe UI", 12),
                         text_color=MUTED, wraplength=840, justify="left").pack(anchor="w", pady=3)

    def _card(self, parent):
        return ctk.CTkFrame(parent, fg_color=PANEL, corner_radius=15,
                            border_width=1, border_color=BORDER)

    @staticmethod
    def _resource_dir():
        # PyInstaller extracts bundled assets into sys._MEIPASS.
        return Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent)) / "resources"

    def _load_resource(self, slug, size=(78, 78)):
        key = (slug, size)
        if key in self._app_images:
            return self._app_images[key]
        path = self._resource_dir() / (slug + ".png")
        if not path.is_file():
            path = self.catalog.root / "icon-cache" / (slug + ".png")
        if not path.is_file():
            return None
        try:
            with Image.open(path) as opened:
                art = opened.convert("RGBA").copy()
            image = ctk.CTkImage(light_image=art, dark_image=art, size=size)
            self._app_images[key] = image
            return image
        except (OSError, ValueError):
            return None

    def _fetch_logo_if_needed(self, app):
        slug = app.icon_slug
        url = app.icon_url
        if not slug or not url or slug in self._image_fetching:
            return
        if self._load_resource(slug):
            return
        parsed = urllib.parse.urlsplit(url)
        if parsed.scheme != "https" or parsed.hostname != "raw.githubusercontent.com":
            return
        if not parsed.path.startswith("/itamarnintendo04-arch/"):
            return
        self._image_fetching.add(slug)
        def task():
            try:
                path = self.catalog.root / "icon-cache" / (slug + ".png")
                path.parent.mkdir(parents=True, exist_ok=True)
                request = urllib.request.Request(url, headers={"User-Agent":"ItamarOS Installer"})
                with urllib.request.urlopen(request, timeout=18) as remote:
                    data = remote.read(2_000_001)
                if len(data) > 2_000_000:
                    return
                from io import BytesIO
                with Image.open(BytesIO(data)) as image:
                    image.convert("RGBA").resize((256, 256), Image.Resampling.LANCZOS).save(path)
                self.events.put(("image-ready", slug, None))
            except (OSError, ValueError):
                pass
            finally:
                self._image_fetching.discard(slug)
        threading.Thread(target=task, daemon=True).start()

    def _set_category(self, category):
        self.category_filter = category
        self._render_apps()

    def show_catalog(self):
        self._clear()
        hero = ctk.CTkFrame(self.content, corner_radius=18, fg_color="#112b45",
                            border_width=1, border_color="#285275")
        hero.pack(fill="x", padx=7, pady=(8, 21))
        left = ctk.CTkFrame(hero, fg_color="transparent")
        left.pack(side="left", fill="x", expand=True, padx=(23, 9), pady=20)
        ctk.CTkLabel(left, text="ITAMAROS APP COLLECTION", font=("Segoe UI", 10, "bold"),
                     text_color="#69e4d4").pack(anchor="w")
        ctk.CTkLabel(left, text="Explore iPhone apps", font=("Segoe UI", 26, "bold"),
                     text_color=WHITE).pack(anchor="w", pady=(6, 3))
        ctk.CTkLabel(left, text="Original app icons, verified projects, fresh versions.",
                     font=("Segoe UI", 12), text_color="#b8d0e3").pack(anchor="w")
        logo = self._load_resource("brand", (92,92))
        if logo:
            ctk.CTkLabel(hero, text="", image=logo, width=100, height=100).pack(side="right", padx=23, pady=9)
        self._section("All ItamarOS iPhone Apps",
                      "Native iOS targets from the ItamarOS source tree plus standalone official iPhone app repositories.")
        stats = ctk.CTkFrame(self.content, fg_color="transparent")
        stats.pack(fill="x", padx=7, pady=(0,13))
        self.all_count = ctk.CTkLabel(stats, text="All apps: 0", text_color=WHITE, font=("Segoe UI", 13, "bold"))
        self.all_count.pack(side="left", padx=(8,18))
        self.ready_count = ctk.CTkLabel(stats, text="Installable: 0", text_color=TEAL, font=("Segoe UI", 13, "bold"))
        self.ready_count.pack(side="left")
        searchbar = ctk.CTkFrame(self.content, fg_color="transparent")
        searchbar.pack(fill="x", padx=7, pady=(0, 12))
        search = ctk.CTkEntry(searchbar, textvariable=self.search_text,
                             placeholder_text="Search by name, category or description...",
                             height=45, corner_radius=12, fg_color=INNER,
                             border_color="#35546a", font=("Segoe UI", 13), text_color=WHITE)
        search.pack(side="left", fill="x", expand=True)
        self.count = ctk.CTkLabel(searchbar, text="", text_color=MUTED)
        self.count.pack(side="right", padx=14)
        chips = ctk.CTkFrame(self.content, fg_color="transparent")
        chips.pack(fill="x", padx=7, pady=(0, 15))
        for category in ("All", "Games", "Creative", "Utilities", "Security", "System", "Apps"):
            ctk.CTkButton(chips, text=category, corner_radius=16, height=30,
                          fg_color=HOVER if self.category_filter == category else "#182a39",
                          hover_color="#236a71", text_color=WHITE, width=64,
                          command=lambda cat=category:self._set_category(cat),
                          font=("Segoe UI", 11, "bold")).pack(side="left", padx=(0,6))
        if hasattr(self, "_search_trace"):
            try: self.search_text.trace_remove("write", self._search_trace)
            except Exception: pass
        self._search_trace = self.search_text.trace_add("write", lambda *_: self._render_apps())
        self.cards_container = ctk.CTkFrame(self.content, fg_color="transparent")
        self.cards_container.pack(fill="both", expand=True, padx=3, pady=5)
        self.cards_container.grid_columnconfigure((0,1), weight=1, uniform="apps")
        self._render_apps()

    def _render_apps(self):
        if not hasattr(self, "cards_container") or not self.cards_container.winfo_exists():
            return
        for child in self.cards_container.winfo_children():
            child.destroy()
        needle = self.search_text.get().strip().lower()
        items = [app for app in self.apps
                 if (not needle or needle in (app.name + " " + app.description + " " + app.category).lower())
                 and (self.category_filter == "All" or app.category == self.category_filter)]
        self.count.configure(text=f"{len(items)} shown")
        if hasattr(self, "all_count") and self.all_count.winfo_exists():
            self.all_count.configure(text=f"All apps: {len(self.apps)}")
            self.ready_count.configure(text=f"Installable: {sum(app.installable() for app in self.apps)}")
        if not items:
            label = "No apps match these filters." if self.apps else "Loading apps from official ItamarOS sources..."
            ctk.CTkLabel(self.cards_container, text=label, text_color=MUTED,
                         font=("Segoe UI",15)).grid(row=0, column=0, columnspan=2, pady=40)
            return
        for idx, app in enumerate(items):
            card = ctk.CTkFrame(self.cards_container, fg_color=PANEL,
                                corner_radius=17, border_width=1, border_color="#263d54")
            card.grid(row=idx//2, column=idx%2, sticky="nsew", padx=7, pady=7)
            top = ctk.CTkFrame(card, fg_color="transparent")
            top.pack(fill="x", padx=16, pady=(18, 9))
            art = self._load_resource(app.icon_slug)
            if art:
                ctk.CTkLabel(top, text="", image=art, width=80, height=80).pack(side="left")
            else:
                placeholder = ctk.CTkFrame(top, width=80,height=80,fg_color="#1b3a52",corner_radius=15)
                placeholder.pack(side="left")
                placeholder.pack_propagate(False)
                ctk.CTkLabel(placeholder,text=app.name[:1].upper(),
                             text_color="#8feedd",font=("Segoe UI",34,"bold")).pack(expand=True)
                self._fetch_logo_if_needed(app)
            detail = ctk.CTkFrame(top, fg_color="transparent")
            detail.pack(side="left", fill="x", expand=True, padx=12)
            ctk.CTkLabel(detail, text=app.category.upper(), font=("Segoe UI",10,"bold"),
                         text_color="#53dac5").pack(anchor="w")
            ctk.CTkLabel(detail, text=app.name, font=("Segoe UI",16,"bold"),
                         text_color=WHITE, anchor="w", wraplength=185, justify="left").pack(anchor="w", pady=(2,4))
            ctk.CTkLabel(detail, text=app.version, font=("Segoe UI",11),
                         text_color=MUTED, anchor="w").pack(anchor="w")
            available = app.installable()
            ctk.CTkLabel(card,text=app.description[:200],wraplength=370,justify="left",
                         text_color="#acc1d2",font=("Segoe UI",12),
                         anchor="nw",height=46).pack(fill="x",padx=19,pady=(3,12))
            statusrow = ctk.CTkFrame(card, fg_color="transparent")
            statusrow.pack(fill="x", padx=19, pady=(0,9))
            ctk.CTkLabel(statusrow,text="●  Ready to install" if available else "○  Source available • IPA not published",
                         text_color=TEAL if available else "#b9aabb",
                         font=("Segoe UI",11),anchor="w").pack(side="left")
            actions = ctk.CTkFrame(card, fg_color="transparent")
            actions.pack(fill="x", padx=17, pady=(0,17))
            ctk.CTkButton(actions,text="Install on iPhone" if available else "Not available yet",
                          command=lambda a=app: self.install_app(a), height=38, corner_radius=11,
                          fg_color=HOVER,hover_color="#19a38d",
                          state="normal" if available else "disabled",
                          font=("Segoe UI",12,"bold")).pack(side="left",fill="x",expand=True)
            ctk.CTkButton(actions, text="View source", command=lambda a=app:webbrowser.open(a.repository_url),
                          width=105,height=38,corner_radius=11,fg_color=INNER,
                          hover_color="#254152",font=("Segoe UI",12)).pack(side="right",padx=(10,0))

    def show_device(self):
        self._clear()
        self._section("My iPhone", "Connect your iPhone by USB, unlock it and choose Trust This Computer.")
        panel=self._card(self.content)
        panel.pack(fill="x",padx=8,pady=12)
        title=ctk.CTkFrame(panel,fg_color="transparent")
        title.pack(fill="x",padx=23,pady=19)
        ctk.CTkLabel(title,text="◉",font=("Segoe UI",35),text_color=TEAL).pack(side="left",padx=(0,20))
        detail=ctk.CTkFrame(title,fg_color="transparent")
        detail.pack(side="left",fill="x",expand=True)
        ctk.CTkLabel(detail,text="USB Device Connection",font=("Segoe UI",17,"bold"),
                     text_color=WHITE).pack(anchor="w")
        service=mobile_device_service_running()
        info="Apple Mobile Device Service: " + (
            "Running" if service is True else "Not detected" if service is False else "Windows required")
        ctk.CTkLabel(detail,text=info,font=("Segoe UI",13),text_color=MUTED).pack(anchor="w",pady=4)
        selector=ctk.CTkFrame(panel,fg_color="transparent")
        selector.pack(fill="x",padx=23,pady=(0,18))
        values=[f"{d['name']} ({d['udid'][:8]}…)" for d in self.devices] or ["No iPhone detected"]
        ctk.CTkOptionMenu(selector,variable=self.device_choice,values=values,
                          command=self._select_device,fg_color=INNER,button_color=HOVER,
                          corner_radius=10,height=40).pack(side="left",fill="x",expand=True)
        ctk.CTkButton(selector,text="Scan Again",fg_color=HOVER,hover_color="#159d88",
                      command=self.scan_device,height=40,width=130).pack(side="right",padx=(12,0))
        ctk.CTkButton(panel, text="Install Drivers", command=self.show_driver_setup,
                      fg_color="#284b62", text_color=WHITE, height=43,
                      font=("Segoe UI", 13, "bold")).pack(fill="x", padx=23, pady=(0, 16))
        ctk.CTkLabel(panel,text="Installations use Apple's mobile device drivers and the pymobiledevice3 helper. "
                     "The IPA must already be properly signed; Apple ID sign-in alone cannot sign an IPA.",
                     text_color=MUTED,wraplength=750,justify="left",font=("Segoe UI",12)).pack(
                         fill="x",padx=23,pady=(0,22))
        ctk.CTkButton(
            panel, text="Install Local IPA over USB (no manifest)",
            command=self.install_local_ipa, height=44, corner_radius=12,
            fg_color=TEAL, text_color=BG, hover_color="#58f1d6",
            font=("Segoe UI", 14, "bold")
        ).pack(fill="x", padx=23, pady=(0, 20))
        if command_for_device_tool() is None:
            ctk.CTkButton(self.content,text="Copy device helper setup instructions",
                          fg_color="#263749",command=self.show_helper_setup,
                          height=43).pack(anchor="w",padx=8,pady=14)

    def show_driver_setup(self):
        """Driver action stays available whether or not Apple software exists."""
        self._clear()
        self._section("Install Drivers", "Official Apple device connection software for Windows.")
        panel = self._card(self.content)
        panel.pack(fill="x", padx=8, pady=12)
        ctk.CTkLabel(panel, text="Apple Devices — Microsoft Store",
                     text_color=WHITE, font=("Segoe UI", 19, "bold")).pack(
                         anchor="w", padx=22, pady=(22, 7))
        self.driver_status = ctk.CTkLabel(
            panel, text="Select Check Drivers to inspect this computer.",
            text_color=MUTED, justify="left", wraplength=730)
        self.driver_status.pack(anchor="w", padx=22, pady=(0, 14))
        ctk.CTkButton(panel, text="Install Drivers", command=self.install_drivers,
                      height=44, fg_color=TEAL, text_color=BG,
                      font=("Segoe UI", 14, "bold")).pack(
                          fill="x", padx=22, pady=(5, 9))
        ctk.CTkButton(panel, text="Check Drivers", command=self.check_apple_drivers,
                      height=41, fg_color="#284b62").pack(
                          fill="x", padx=22, pady=(0, 9))
        ctk.CTkButton(panel, text="Open Official Microsoft Store",
                      command=self.open_apple_store, height=41,
                      fg_color="#284b62").pack(fill="x", padx=22, pady=(0, 15))
        ctk.CTkLabel(panel,
                     text="Install Drivers always remains available. You can install or update "
                          "Apple Devices using Microsoft's official Store. After installation, "
                          "connect the iPhone by USB, unlock it and tap Trust This Computer. "
                          "Wi-Fi Sync does not guarantee wireless IPA installation. "
                          "The separate pymobiledevice3 helper may still be required.",
                     text_color=MUTED, wraplength=740, justify="left").pack(
                         anchor="w", padx=22, pady=(0, 20))
        self.after(100, self.check_apple_drivers)

    def check_apple_drivers(self):
        if self.busy:
            self.status.configure(text="Finish the current operation, then check drivers.")
            return
        if hasattr(self, "driver_status") and self.driver_status.winfo_exists():
            self.driver_status.configure(text="Checking installed Apple components…")
        self.status.configure(text="Checking Apple device drivers…")
        self._run(check_drivers, self._drivers_checked)

    def _drivers_checked(self, result):
        service_label = {
            "running": "Running", "stopped": "Installed but stopped",
            "missing": "Not detected", "unavailable": "Could not check",
            "unsupported": "Windows only",
        }.get(result.service, result.service)
        info = (
            f"Apple Mobile Device Service: {service_label}\\n"
            f"Apple Devices app: {'Installed' if result.apple_devices_app else 'Not detected'}\\n"
            f"Windows Package Manager: {'Available' if result.winget_available else 'Unavailable'}\\n"
            "The button remains available even when Apple software is installed."
        )
        if hasattr(self, "driver_status") and self.driver_status.winfo_exists():
            self.driver_status.configure(text=info)
        self.status.configure(text="Apple driver check completed")

    def install_drivers(self):
        if sys.platform != "win32":
            messagebox.showinfo("Install Drivers", "Apple device drivers can be installed on Windows 10 or 11.")
            return
        if self.busy:
            messagebox.showinfo("Install Drivers", "Finish the current operation before installing drivers.")
            return
        answer = messagebox.askyesno(
            "Install Drivers",
            "Install or update Apple Devices from the official Microsoft Store?\\n\\n"
            "ItamarOS will use Windows Package Manager (winget) if it is available. "
            "Microsoft Store agreements will be accepted for this installation. "
            "If winget is unavailable, the Store page will open instead.\\n\\n"
            "Windows may request permission. Continue?"
        )
        if not answer:
            return
        self.status.configure(text="Installing Apple Devices from Microsoft Store…")
        self._run(install_apple_devices, self._drivers_installed)

    def _drivers_installed(self, result):
        installed, info = result
        if installed:
            self.status.configure(text="Apple Devices installation command completed")
            messagebox.showinfo(
                "Install Drivers",
                info + "\\n\\nReconnect the iPhone, unlock it, tap Trust and use Check Drivers."
            )
        else:
            self.status.configure(text="Open Microsoft Store to finish installing Apple Devices")
            messagebox.showwarning(
                "Install Drivers",
                info + "\\n\\nThe official Microsoft Store page will open so you can install or repair Apple Devices."
            )
            open_official_store()
        self.check_apple_drivers()

    def open_apple_store(self):
        if not open_official_store():
            messagebox.showerror("Install Drivers", "Unable to open the Microsoft Store in your browser.")

    def show_certificates(self):
        self._clear()
        self._section("Signing Certificates",
                      "Certificates stay on this computer. Paired iPhones only receive names, expiry and availability.")
        panel = self._card(self.content)
        panel.pack(fill="x", padx=8, pady=12)
        ctk.CTkButton(panel, text="Add P12 and provisioning profile",
                      command=self.add_desktop_certificate, height=42,
                      fg_color=TEAL, text_color=BG).pack(anchor="w", padx=20, pady=(16, 6))
        ctk.CTkButton(panel, text="Import ZIP archives (select multiple)",
                      command=self.import_certificate_zips, height=42,
                      fg_color="#284b62", text_color=WHITE).pack(anchor="w", padx=20, pady=(4, 16))
        entries = self.desktop_certificates.public_list()
        if not entries:
            ctk.CTkLabel(panel, text="No desktop certificates imported.",
                         text_color=MUTED).pack(anchor="w", padx=20, pady=14)
        for cert in entries:
            line = ctk.CTkFrame(panel, fg_color=INNER)
            line.pack(fill="x", padx=20, pady=5)
            state = "Available" if cert["available"] else "Expired or missing file"
            ctk.CTkLabel(line, text=f'{cert["name"][:100]}  |  {state}  |  {cert["expires"][:10]}',
                         text_color=WHITE, anchor="w").pack(side="left", padx=12, pady=12)
            ctk.CTkButton(line, text="Remove", width=90,
                          command=lambda key=cert["id"]: self.remove_desktop_certificate(key)
                          ).pack(side="right", padx=8)
        ctk.CTkLabel(panel,
                     text="Only metadata is synchronized. P12 passwords are never saved. "
                          "Importing a certificate does not enable automatic IPA signing.",
                     wraplength=720, text_color=MUTED).pack(anchor="w", padx=20, pady=18)

    def add_desktop_certificate(self):
        p12 = filedialog.askopenfilename(title="Select your Apple-issued P12",
                                         filetypes=[("P12 certificates", "*.p12")])
        if not p12:
            return
        profile = filedialog.askopenfilename(title="Select provisioning profile (optional)",
                                             filetypes=[("Provisioning profiles", "*.mobileprovision")])
        password = simpledialog.askstring("P12 Password", "Enter P12 password (not saved):",
                                          show="*", parent=self)
        if password is None:
            return
        try:
            self.desktop_certificates.import_identity(p12, password, profile)
        except (ValueError, OSError) as exc:
            messagebox.showerror("Certificate import", str(exc))
        self.show_certificates()

    def _request_archive_password(self, certificate_name, archive_name, text_notes):
        """Display every TXT note from the ZIP during password entry."""
        dialog = ctk.CTkToplevel(self)
        dialog.title("Certificate password — local only")
        dialog.geometry("660x485" if text_notes else "560x245")
        dialog.minsize(500, 230)
        dialog.transient(self)
        result = {"value": None}
        ctk.CTkLabel(dialog,
                     text=f"Certificate: {certificate_name[:90]}\nArchive: {archive_name[:90]}",
                     text_color=WHITE, justify="left", wraplength=590).pack(
                         anchor="w", padx=20, pady=(18, 8))
        if text_notes:
            ctk.CTkLabel(dialog, text="TXT contents from this ZIP (read-only; not sent to any server):",
                         text_color=MUTED).pack(anchor="w", padx=20)
            textbox = ctk.CTkTextbox(dialog, height=175, wrap="word")
            textbox.pack(fill="both", expand=True, padx=20, pady=(5, 12))
            for filename, note in text_notes:
                textbox.insert("end", f"=== {filename} ===\n{note}\n\n")
            textbox.configure(state="disabled")
        else:
            ctk.CTkLabel(dialog, text="No TXT note found in this ZIP.",
                         text_color=MUTED).pack(anchor="w", padx=20, pady=6)
        ctk.CTkLabel(dialog, text="P12 password (never saved):",
                     text_color=WHITE).pack(anchor="w", padx=20, pady=(5, 3))
        entry = ctk.CTkEntry(dialog, show="*", width=610)
        entry.pack(fill="x", padx=20, pady=(0, 12))
        buttons = ctk.CTkFrame(dialog, fg_color="transparent")
        buttons.pack(fill="x", padx=20, pady=(0, 18))
        def finish(accepted):
            if accepted:
                result["value"] = entry.get()
            entry.delete(0, "end")
            dialog.destroy()
        ctk.CTkButton(buttons, text="Import certificate", height=38,
                      command=lambda: finish(True),
                      fg_color=TEAL, text_color=BG).pack(side="left")
        ctk.CTkButton(buttons, text="Skip", height=38,
                      command=lambda: finish(False),
                      fg_color="#283948").pack(side="right")
        dialog.protocol("WM_DELETE_WINDOW", lambda: finish(False))
        dialog.grab_set()
        entry.focus_set()
        self.wait_window(dialog)
        return result["value"]

    def import_certificate_zips(self):
        archives = filedialog.askopenfilenames(
            title="Select one or more certificate ZIP archives",
            filetypes=[("ZIP archives", "*.zip")],
            parent=self,
        )
        if not archives:
            return
        try:
            identities = extract_archives(list(archives))
        except (OSError, ValueError) as exc:
            messagebox.showerror("Certificate ZIP import", str(exc))
            return
        imported = 0
        failures = []
        for item in identities:
            password = self._request_archive_password(
                item.certificate_name, item.archive_name, item.txt_notes)
            if password is None:
                continue
            try:
                self.desktop_certificates.import_identity(
                    item.p12_path, password, item.profile_path)
                imported += 1
            except (OSError, ValueError, TypeError) as exc:
                failures.append(item.certificate_name + ": " + str(exc)[:160])
            finally:
                password = None
        message = f"Imported {imported} certificate(s) from {len(archives)} ZIP archive(s)."
        if failures:
            message += "\n\nSome certificates failed:\n" + "\n".join(failures[:10])
        messagebox.showinfo("Certificate ZIP import", message)
        self.show_certificates()

    def remove_desktop_certificate(self, identity_id):
        if messagebox.askyesno("Remove certificate", "Remove this signing identity from ItamarOS? The original file will not be deleted."):
            self.desktop_certificates.remove(identity_id)
            self.show_certificates()

    def show_wifi_companion(self):
        self._clear()
        self._section("Wi-Fi Companion",
                      "Pair with ItamarOS Installer on the same private Wi-Fi network. "
                      "Only a trusted iPhone can read device details or request app installs.")
        panel = self._card(self.content)
        panel.pack(fill="x", padx=8, pady=12)
        if not self.lan_server:
            ctk.CTkLabel(panel,
                         text="Server is off. Start it to show a temporary QR pairing code.",
                         wraplength=760, font=("Segoe UI",14), text_color=MUTED).pack(
                         padx=20, pady=(24,14))
            ctk.CTkButton(panel, text="Start secure Wi-Fi server",
                          command=self.start_wifi_server, height=45,
                          fg_color=TEAL, text_color=BG).pack(padx=20, pady=(0,22))
            return
        server = self.lan_server
        ctk.CTkLabel(panel,
                     text=f"Server: https://{local_ipv4()}:{server.port}\n"
                          f"Pair code (valid 10 minutes): {server.pair_code}\n"
                          "The pairing QR pins this server's TLS fingerprint; "
                          "do not share it with people outside your private network.",
                     text_color=WHITE, font=("Segoe UI",13),
                     wraplength=750, justify="left").pack(padx=20,pady=(18,12))
        try:
            qr = qrcode.make(server.pairing_url).convert("RGB").resize((264,264))
            self.lan_image = ctk.CTkImage(light_image=qr, dark_image=qr, size=(264,264))
            ctk.CTkLabel(panel, text="", image=self.lan_image).pack(pady=5)
        except Exception:
            pass
        buttons = ctk.CTkFrame(panel, fg_color="transparent")
        buttons.pack(padx=20,pady=(13,18))
        ctk.CTkButton(buttons,text="Rotate pairing code",command=self.rotate_wifi_code,
                      height=38).pack(side="left",padx=8)
        ctk.CTkButton(buttons,text="Stop server",command=self.stop_wifi_server,
                      fg_color="#754149",height=38).pack(side="left",padx=8)
        ctk.CTkLabel(self.content,
                     text="First pair your iPhone with this computer using USB and tap Trust. "
                          "In Apple Devices (or iTunes), enable syncing over Wi-Fi if needed. "
                          "Apple device pairing is separate from this QR connection. "
                          "Wi-Fi installation works only if the supported device helper "
                          "actually detects the paired iPhone. Official apps come from "
                          "ItamarOS GitHub Releases automatically; current unsigned previews "
                          "require your own authorized signing before iOS can install them.",
                     text_color=MUTED, wraplength=820, justify="left").pack(
                     anchor="w",padx=20,pady=12)

    def start_wifi_server(self):
        if self.lan_server is not None:
            return
        def task():
            try:
                self.official.refresh()
                server = CompanionServer(
                    get_devices=lambda: list(self.devices),
                    get_apps=lambda: self.official.list_apps(),
                    get_certificates=lambda: self.desktop_certificates.public_list(),
                    on_request=lambda req: self.events.put(("lan-request",req,None)),
                )
                server.start()
                self.lan_server = server
                self.events.put(("lan-started",None,None))
            except Exception as exc:
                self.events.put(("lan-start-error",str(exc),None))
        threading.Thread(target=task,daemon=True).start()
        self.status.configure(text="Starting the private Wi-Fi companion…")

    def rotate_wifi_code(self):
        if self.lan_server:
            self.lan_server.rotate_code()
            self.show_wifi_companion()

    def stop_wifi_server(self):
        if self.lan_server:
            self.lan_server.stop()
            self.lan_server = None
        self.show_wifi_companion()

    def _approve_lan_install(self, request: InstallRequest):
        if self.lan_server is None:
            return
        app = next((a for a in self.official.list_apps() if a["id"]==request.app_id),None)
        if app is None:
            self.lan_server.finish_request(request.id,"denied","Unknown official app.")
            return
        target = next((d for d in self.devices if d["udid"]==request.target_udid), None)
        if target is None:
            self.lan_server.finish_request(request.id,"denied","iPhone not detected.")
            return
        if not messagebox.askyesno("Wi-Fi installation request",
                                  f"The paired iPhone requests {app['name']}.\n\n"
                                  f"Target: {target['name']}\n\n"
                                  "Download this official IPA automatically from "
                                  "ItamarOS GitHub Releases? If it is unsigned, "
                                  "you must sign it yourself before installation."):
            self.lan_server.finish_request(request.id,"denied","Declined on the computer.")
            return
        self.lan_server.finish_request(request.id,"downloading")
        def job():
            file, signed = self.official.download(request.app_id)
            if not signed:
                return ("requires_signing",
                        "Official IPA downloaded to the computer. "
                        "It is unsigned; use an authorized signing certificate "
                        "and provisioning profile before it can be installed.")
            return ("installed", install_ipa(file,request.target_udid))
        def completed(result):
            state, info = result
            if self.lan_server:
                self.lan_server.finish_request(request.id,state,str(info))
            if state == "requires_signing":
                messagebox.showinfo("Official app downloaded",
                                    f"{app['name']} was downloaded automatically. "
                                    "This release is unsigned, so iOS cannot install it yet. "
                                    "Sign the IPA with your authorized certificate first.")
            else:
                messagebox.showinfo("Installation completed",
                                    f"{app['name']} was installed on the iPhone.")
        if self.busy:
            self.lan_server.finish_request(request.id,"failed",
                                          "Desktop is currently busy; request again shortly.")
        else:
            self.busy = True
            self.refresh_button.configure(state="disabled")
            self.progress.set(0)
            def lan_worker():
                try:
                    result = job()
                    self.events.put(("lan-job-complete", result, completed))
                except Exception as exc:
                    self.events.put(("lan-job-failed", (request.id, str(exc)), None))
            threading.Thread(target=lan_worker, daemon=True).start()

    def _select_device(self, text):
        for device in self.devices:
            if device["udid"][:8] in text:
                self.selected_udid=device["udid"]
                return

    def open_downloads(self):
        DOWNLOAD_DIR.mkdir(parents=True,exist_ok=True)
        if sys.platform == "win32":
            os.startfile(str(DOWNLOAD_DIR))
        else:
            messagebox.showinfo("Downloads",str(DOWNLOAD_DIR))

    def show_helper_setup(self):
        instructions=("1. Install iTunes for Windows including Apple Mobile Device Support.\n"
                      "2. Install Python from python.org.\n"
                      "3. Open Windows Terminal and run:\n"
                      "     py -m pip install --user pymobiledevice3\n"
                      "4. Restart ItamarOS Installer, connect your iPhone and tap Trust.\n"
                      "This is a device communication tool; it does not sign IPA files.")
        self.clipboard_clear()
        self.clipboard_append("py -m pip install --user pymobiledevice3")
        messagebox.showinfo("Device Helper Setup",instructions+"\n\nThe install command was copied to clipboard.")

    def apple_login(self):
        messagebox.showinfo("Sign in with Apple",
            "Apple account sign-in must use Apple's official browser-based OAuth flow.\n\n"
            "ItamarOS must first register a Sign in with Apple Services ID and a secure callback "
            "on its server. This build does not collect your Apple ID password or claim a signed-in "
            "session. Apple ID sign-in cannot automatically sign arbitrary IPA files.\n\n"
            "The public app catalog works without Apple sign-in.")
        webbrowser.open("https://developer.apple.com/help/account/capabilities/configure-sign-in-with-apple-for-the-web")

    def _run(self, job, success=None):
        if self.busy:
            self.status.configure(text="An operation is already in progress.")
            return
        self.busy=True
        self.refresh_button.configure(state="disabled")
        self.progress.set(0)
        def worker():
            try:
                result=job()
                self.events.put(("success",result,success))
            except Exception as exc:
                self.events.put(("error",str(exc),None))
        threading.Thread(target=worker,daemon=True).start()

    def _handle_events(self):
        try:
            while True:
                kind,value,callback=self.events.get_nowait()
                if kind=="progress":
                    self.progress.set(value)
                    continue
                if kind=="image-ready":
                    self._render_apps()
                    continue
                if kind=="lan-request":
                    self._approve_lan_install(value)
                    continue
                if kind=="lan-started":
                    self.show_wifi_companion()
                    continue
                if kind=="lan-start-error":
                    self.status.configure(text="Wi-Fi server unavailable")
                    messagebox.showerror("Wi-Fi Companion", str(value))
                    continue
                if kind=="lan-job-failed":
                    request_id, reason = value
                    if self.lan_server:
                        self.lan_server.finish_request(request_id, "failed", reason)
                    self.busy=False
                    self.refresh_button.configure(state="normal")
                    self.status.configure(text="Installation failed")
                    messagebox.showerror("Installation failed", reason)
                    continue
                if kind=="lan-job-complete":
                    self.busy=False
                    self.refresh_button.configure(state="normal")
                    callback(value)
                    continue
                self.busy=False
                self.refresh_button.configure(state="normal")
                if kind=="error":
                    if self.lan_server:
                        with self.lan_server.guard:
                            for key, value0 in self.lan_server.requests.items():
                                if value0.get("state") == "downloading":
                                    self.lan_server.finish_request(key, "failed", str(value))
                    self.status.configure(text="Operation failed")
                    messagebox.showerror("ItamarOS Installer",value)
                elif callback:
                    try: callback(value)
                    except Exception as exc: messagebox.showerror("ItamarOS Installer",str(exc))
        except queue.Empty:
            pass
        self.after(120,self._handle_events)

    def refresh_catalog(self,force=False):
        self.status.configure(text="Checking latest ItamarOS releases...")
        self._run(lambda: self.catalog.refresh(force=force),self._catalog_ready)

    def _catalog_ready(self,apps):
        self.apps=apps
        self.status.configure(text=f"Catalog current • {len(apps)} iPhone apps • ItamarOS sources + GitHub Releases")
        self.progress.set(1)
        self._render_apps()
        if not self.devices and command_for_device_tool() is not None:
            self.after(300, self.scan_device)

    def scan_device(self):
        if self.busy: return
        self.status.configure(text="Scanning for iPhones over USB...")
        self._run(scan_devices,self._device_ready)

    def _device_ready(self,devices):
        self.devices=devices
        self.selected_udid=devices[0]["udid"] if devices else ""
        self.device_choice.set(f"{devices[0]['name']} ({devices[0]['udid'][:8]}…)"
                               if devices else "No iPhone detected")
        self.status.configure(text=(f"{len(devices)} iPhone(s) connected" if devices
                                    else "No iPhone found — check USB, Trust, drivers and device helper."))
        self.progress.set(1)
        if not hasattr(self,"cards_container") or not self.cards_container.winfo_exists():
            self.show_device()

    def install_local_ipa(self):
        """Install a signed IPA selected from local disk using Apple's USB device service.

        No manifest, remote hosting, or P12 upload required. Apple/iOS rejects
        invalid signatures and profiles. This does not sign the IPA.
        """
        if not self.selected_udid:
            messagebox.showwarning("No iPhone", "Connect and select your trusted iPhone under My iPhone first.")
            self.show_device()
            return
        if command_for_device_tool() is None:
            messagebox.showerror(
                "Device helper missing",
                "Install the supported iPhone USB helper before installing IPA files. "
                "See My iPhone → Copy device helper setup instructions."
            )
            return
        selected=filedialog.askopenfilename(
            title="Choose a signed IPA for your iPhone",
            filetypes=[("iPhone IPA files", "*.ipa"), ("All files", "*.*")]
        )
        if not selected:
            return
        source=Path(selected)
        try:
            if source.suffix.lower() != ".ipa" or not source.is_file() or source.stat().st_size > 2_000_000_000:
                raise ValueError("Choose a local IPA smaller than 2 GB.")
            with zipfile.ZipFile(source) as archive:
                infos=[item.filename for item in archive.infolist()
                       if item.filename.startswith("Payload/")
                       and item.filename.count("/") == 2
                       and item.filename.endswith(".app/Info.plist")
                       and item.file_size < 1_000_000]
                if len(infos) != 1:
                    raise ValueError("IPA must contain one app with an Info.plist.")
                info=plistlib.loads(archive.read(infos[0]))
                display=info.get("CFBundleDisplayName") or info.get("CFBundleName") or source.name
                bundle=info.get("CFBundleIdentifier")
                if not isinstance(bundle,str) or not bundle:
                    raise ValueError("IPA lacks a valid Bundle ID.")
        except (OSError, ValueError, zipfile.BadZipFile, plistlib.InvalidFileException) as exc:
            messagebox.showerror("Invalid IPA", str(exc))
            return
        if not messagebox.askyesno(
            "Install Local IPA",
            f"App: {display}\\nBundle ID: {bundle}\\n\\n"
            "Install this file on the connected iPhone over USB?\\n\\n"
            "It must already be signed by an authorized Apple-issued identity "
            "and provisioned for this device. iOS makes the final decision."
        ):
            return
        self.status.configure(text="Installing local IPA over USB…")
        self._run(lambda: install_ipa(source,self.selected_udid),
                  lambda _: self._install_local_ready(str(display)))

    def _install_local_ready(self, name):
        self.status.configure(text=name+" installed successfully over USB")
        messagebox.showinfo("Installation Complete",
            name+" was installed using the selected local IPA. No manifest was needed.")

    def install_app(self,app):
        if not self.selected_udid:
            messagebox.showwarning("No iPhone", "Connect and select an iPhone under My iPhone first.")
            self.show_device()
            return
        choice=messagebox.askyesno("Install "+app.name,
            f"Download and install {app.name} {app.version} onto the selected iPhone?\n\n"
            "Only an IPA signed for this device will install successfully.")
        if not choice: return
        self.status.configure(text="Downloading "+app.name+"...")
        def job():
            file=download_ipa(app,on_progress=lambda portion: self.events.put(("progress",portion,None)))
            self.events.put(("progress",1,None))
            return install_ipa(file,self.selected_udid)
        self._run(job,lambda _: self._install_ready(app))

    def _install_ready(self,app):
        self.status.configure(text=app.name+" installed successfully")
        messagebox.showinfo("Installation Complete",
                            app.name+" was successfully installed on your iPhone.")

    def _periodic_refresh(self):
        if not self.busy:
            self.refresh_catalog(force=False)
        self.after(1_200_000,self._periodic_refresh)

    def _close(self):
        if self.lan_server:
            self.lan_server.stop()
            self.lan_server = None
        self.destroy()


if __name__ == "__main__":
    Installer().mainloop()
