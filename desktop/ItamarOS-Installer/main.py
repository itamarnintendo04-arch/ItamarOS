"""ItamarOS Installer — desktop application for Windows."""
from __future__ import annotations

import os
import queue
import sys
import threading
import webbrowser
from pathlib import Path
from tkinter import messagebox

import customtkinter as ctk
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


class Installer(ctk.CTk):
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
        self.search_text = ctk.StringVar()
        self.device_choice = ctk.StringVar(value="No iPhone selected")
        self._init_shell()
        self.after(100, self._handle_events)
        self.after(180, lambda: self.refresh_catalog(force=False))
        self.after(400, self.scan_device)
        self.after(300_000, self._periodic_refresh)

    def _init_shell(self):
        self.grid_columnconfigure(1, weight=1)
        self.grid_rowconfigure(0, weight=1)
        side = ctk.CTkFrame(self, width=248, corner_radius=0, fg_color="#0d1824")
        side.grid(row=0, column=0, sticky="nsew")
        side.grid_propagate(False)
        logo = ctk.CTkFrame(side, height=68, fg_color="transparent")
        logo.pack(fill="x", padx=20, pady=(24, 28))
        ctk.CTkLabel(logo, text="✦", font=("Segoe UI", 31, "bold"), text_color=TEAL).pack(side="left")
        ctk.CTkLabel(logo, text="ItamarOS\nInstaller", font=("Segoe UI", 20, "bold"),
                     text_color=WHITE, justify="left").pack(side="left", padx=12)
        self._nav(side, "▦  App Catalog", self.show_catalog)
        self._nav(side, "◉  My iPhone", self.show_device)
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
        ctk.CTkLabel(side, text="ItamarOS Installer v1.0\nWindows 10 / 11",
                     text_color="#7892a1", font=("Segoe UI", 11), justify="left").pack(
                         side="bottom", anchor="w", padx=24, pady=24)

        self.main = ctk.CTkFrame(self, fg_color=BG, corner_radius=0)
        self.main.grid(row=0, column=1, sticky="nsew")
        self.main.grid_columnconfigure(0, weight=1)
        self.main.grid_rowconfigure(1, weight=1)
        header = ctk.CTkFrame(self.main, fg_color="transparent")
        header.grid(row=0, column=0, sticky="ew", padx=30, pady=(27, 16))
        ctk.CTkLabel(header, text="Discover • Install • Update", text_color=WHITE,
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
        self.show_catalog()

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

    def show_catalog(self):
        self._clear()
        self._section("iPhone App Catalog",
            "Always shows the latest releases published by official ItamarOS GitHub projects. Newly tagged iOS projects appear automatically.")
        toolbar = ctk.CTkFrame(self.content, fg_color="transparent")
        toolbar.pack(fill="x", padx=8, pady=(0, 14))
        entry = ctk.CTkEntry(toolbar, textvariable=self.search_text,
                             placeholder_text="Search ItamarOS apps...", height=42,
                             corner_radius=12, fg_color=INNER, border_color=BORDER,
                             font=("Segoe UI", 13), text_color=WHITE)
        entry.pack(side="left", fill="x", expand=True)
        if hasattr(self, "_search_trace"):
            try: self.search_text.trace_remove("write", self._search_trace)
            except Exception: pass
        self._search_trace = self.search_text.trace_add("write", lambda *_: self._render_apps())
        self.count = ctk.CTkLabel(toolbar, text="", text_color=MUTED)
        self.count.pack(side="right", padx=14)
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
        items = [a for a in self.apps if needle in (a.name + " " + a.description).lower()]
        self.count.configure(text=f"{len(items)} apps")
        if not items:
            text = "No matching apps." if self.apps else "Loading catalog — or no official iOS releases have been published yet."
            ctk.CTkLabel(self.cards_container, text=text, text_color=MUTED,
                         font=("Segoe UI", 15), wraplength=690).grid(row=0,column=0,columnspan=2,pady=36)
            return
        for idx, app in enumerate(items):
            card = self._card(self.cards_container)
            card.grid(row=idx//2, column=idx%2, sticky="nsew", padx=7,pady=7)
            top=ctk.CTkFrame(card,fg_color="transparent")
            top.pack(fill="x", padx=19,pady=(18,7))
            ctk.CTkLabel(top,text="◈",font=("Segoe UI",29,"bold"),text_color=TEAL).pack(side="left")
            title=ctk.CTkFrame(top,fg_color="transparent")
            title.pack(side="left",fill="x",expand=True,padx=10)
            ctk.CTkLabel(title,text=app.name,anchor="w",font=("Segoe UI",17,"bold"),
                         text_color=WHITE).pack(anchor="w")
            ctk.CTkLabel(title,text=app.version,anchor="w",font=("Segoe UI",11),
                         text_color=MUTED).pack(anchor="w",pady=2)
            badge="IPA AVAILABLE" if app.installable() else "NOT RELEASED"
            ctk.CTkLabel(top,text=badge,text_color=TEAL if app.installable() else "#b5a9b0",
                         font=("Segoe UI",10,"bold")).pack(side="right",anchor="n",padx=1,pady=3)
            ctk.CTkLabel(card,text=app.description[:185],wraplength=380,justify="left",
                         text_color="#a9bfcb",font=("Segoe UI",12),
                         height=48,anchor="nw").pack(fill="x",padx=20,pady=(2,12))
            actions=ctk.CTkFrame(card,fg_color="transparent")
            actions.pack(fill="x",padx=18,pady=(0,18))
            ctk.CTkButton(actions,text="Install on iPhone" if app.installable() else "No IPA yet",
                          command=lambda a=app: self.install_app(a),
                          height=37,corner_radius=10,fg_color=HOVER,hover_color="#1da68d",
                          state="normal" if app.installable() else "disabled",
                          font=("Segoe UI",12,"bold")).pack(side="left",fill="x",expand=True)
            ctk.CTkButton(actions,text="Repository",command=lambda a=app: webbrowser.open(a.repository_url),
                          width=92,height=37,corner_radius=10,fg_color=INNER,hover_color="#254152",
                          font=("Segoe UI",12)).pack(side="right",padx=(9,0))

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
        ctk.CTkLabel(panel,text="Installations use Apple's mobile device drivers and the pymobiledevice3 helper. "
                     "The IPA must already be properly signed; Apple ID sign-in alone cannot sign an IPA.",
                     text_color=MUTED,wraplength=750,justify="left",font=("Segoe UI",12)).pack(
                         fill="x",padx=23,pady=(0,22))
        if command_for_device_tool() is None:
            ctk.CTkButton(self.content,text="Copy device helper setup instructions",
                          fg_color="#263749",command=self.show_helper_setup,
                          height=43).pack(anchor="w",padx=8,pady=14)

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
                self.busy=False
                self.refresh_button.configure(state="normal")
                if kind=="error":
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
        self.status.configure(text=f"Catalog up to date • {len(apps)} projects • Checked GitHub Releases")
        self.progress.set(1)
        self._render_apps()

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
            self.refresh_catalog(force=True)
        self.after(300_000,self._periodic_refresh)

    def _close(self):
        self.destroy()


if __name__ == "__main__":
    Installer().mainloop()
