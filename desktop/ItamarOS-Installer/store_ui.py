"""Desktop App Store screens for ItamarOS Installer.

Provides Discover, Apps, Games, Updates, Library and Sources through the
existing CustomTkinter shell. First-party apps and games remain in the
undeletable official catalog; community sources are explicitly labeled.
"""
from __future__ import annotations

import os
import sys
import webbrowser
from pathlib import Path
from tkinter import messagebox

import customtkinter as ctk

STORE_BLUE = "#4f84f4"
STORE_MUTED = "#9fb5ca"
STORE_PANEL = "#12233b"
STORE_BORDER = "#334864"


class StoreUIMixin:
    def show_store(self, section="Discover"):
        self.store_section = section
        self._clear()
        self._section("ItamarOS Store" if section == "Discover" else section,
                      "Official ItamarOS apps, games and opt-in community catalogs. "
                      "All unsigned previews require Apple signing before installation.")
        tabs = ctk.CTkFrame(self.content, fg_color="transparent")
        tabs.pack(fill="x", padx=7, pady=(4, 14))
        for label in ("Discover", "Apps", "Games", "Updates", "Library", "Sources"):
            ctk.CTkButton(
                tabs, text=label, height=36, corner_radius=18, width=93,
                fg_color=STORE_BLUE if label == section else "#1c2c42",
                hover_color="#356ac9",
                command=lambda choice=label: self.show_store(choice)
            ).pack(side="left", padx=(0, 7))
        if section == "Sources":
            self._render_sources()
            return
        if section == "Discover":
            feature = self._card(self.content)
            feature.pack(fill="x", padx=7, pady=8)
            ctk.CTkLabel(feature, text="FEATURED • ITAMAROS OFFICIAL",
                         font=("Segoe UI", 11, "bold"),
                         text_color="#8cb8ff").pack(anchor="w", padx=20, pady=(17, 2))
            ctk.CTkLabel(feature, text="Apps for every day. Games for every moment.",
                         font=("Segoe UI", 22, "bold"), text_color="#f1f6ff",
                         wraplength=780).pack(anchor="w", padx=20)
            ctk.CTkLabel(feature,
                         text="ItamarCut · BrowserOS · Voice Recorder · Screen Balance · Cloud Climb",
                         font=("Segoe UI", 12), text_color=STORE_MUTED
                         ).pack(anchor="w", padx=20, pady=(8, 18))
        if section in ("Discover", "Apps", "Games"):
            search = ctk.CTkEntry(self.content, textvariable=self.store_search_var,
                                  placeholder_text="Search apps, developers and categories…",
                                  fg_color="#1b2a40", height=43)
            search.pack(fill="x", padx=7, pady=(8, 13))
        self.store_cards = ctk.CTkFrame(self.content, fg_color="transparent")
        self.store_cards.pack(fill="both", expand=True, padx=5, pady=5)
        self.store_cards.grid_columnconfigure((0, 1), weight=1, uniform="storefront")
        self._render_store_cards()
        if not self.store_rows and not self.busy:
            self._refresh_store()

    def _refresh_store(self):
        if self.busy:
            return
        self.status.configure(text="Refreshing official and community app sources…")
        self._run(self.store_sources.refresh, self._store_ready)

    def _store_ready(self, result):
        apps, errors = result
        self.store_rows = apps
        self.status.configure(text=f"Store updated • {len(apps)} apps • "
                                   f"{len(self.store_sources.sources)} community sources")
        if errors:
            messagebox.showwarning("Community Source Error",
                                   "\n".join(errors)[:900])
        if self.store_section == "Sources":
            self.show_store("Sources")
        elif hasattr(self, "store_cards") and self.store_cards.winfo_exists():
            self._render_store_cards()

    def _store_items_for_section(self):
        needle = self.store_search_var.get().strip().lower()
        rows = []
        for app in self.store_rows:
            is_game = app.get("category", "").lower() == "games"
            if self.store_section == "Games" and not is_game:
                continue
            if self.store_section == "Apps" and is_game:
                continue
            if self.store_section in ("Updates", "Library") and not self._has_store_download(app):
                continue
            fields = " ".join(str(app.get(field, "")) for field
                              in ("name", "description", "category", "developer", "source_name")).lower()
            if needle and needle not in fields:
                continue
            rows.append(app)
        return rows

    def _has_store_download(self, app):
        if app.get("official"):
            folder = self.official.folder
            name = app.get("download_url", "").split("/")[-1]
            return (folder / name).is_file()
        folder = self.store_sources.file.parent / "CommunityDownloads"
        filename = app["source_id"] + "-" + app["app_id"] + ".ipa"
        return (folder / filename).is_file()

    def _render_store_cards(self):
        frame = getattr(self, "store_cards", None)
        if frame is None or not frame.winfo_exists():
            return
        for child in frame.winfo_children():
            child.destroy()
        rows = self._store_items_for_section()
        if not rows:
            text = ("No downloaded IPAs in the library." if self.store_section == "Library"
                    else "No update candidates: download an IPA first." if self.store_section == "Updates"
                    else "No apps to display. Refresh your app sources.")
            ctk.CTkLabel(frame, text=text, text_color=STORE_MUTED,
                         font=("Segoe UI", 14)).grid(row=0, column=0, pady=35)
            return
        for index, app in enumerate(rows):
            card = ctk.CTkFrame(frame, fg_color=STORE_PANEL,
                                border_width=1, border_color=STORE_BORDER,
                                corner_radius=18)
            card.grid(row=index // 2, column=index % 2, sticky="nsew", padx=8, pady=8)
            top = ctk.CTkFrame(card, fg_color="transparent")
            top.pack(fill="x", padx=15, pady=(18, 6))
            logo = ctk.CTkFrame(top, width=68, height=68,
                                fg_color="#254b8e" if app["official"] else "#50406f",
                                corner_radius=15)
            logo.pack(side="left")
            logo.pack_propagate(False)
            ctk.CTkLabel(logo, text=app["name"][:1].upper(),
                         font=("Segoe UI", 33, "bold"), text_color="#fff").pack(expand=True)
            info = ctk.CTkFrame(top, fg_color="transparent")
            info.pack(side="left", fill="both", expand=True, padx=(12, 0))
            ctk.CTkLabel(info, text="OFFICIAL" if app["official"] else "COMMUNITY SOURCE",
                         text_color="#5fb5ff" if app["official"] else "#f0b15d",
                         font=("Segoe UI", 10, "bold")).pack(anchor="w")
            ctk.CTkLabel(info, text=app["name"], text_color="#fff",
                         font=("Segoe UI", 16, "bold"), wraplength=210,
                         justify="left").pack(anchor="w")
            ctk.CTkLabel(info, text=app.get("category", "Apps") +
                         " · " + app.get("developer", ""),
                         font=("Segoe UI", 10), text_color=STORE_MUTED,
                         wraplength=210, justify="left").pack(anchor="w")
            ctk.CTkLabel(card, text=app.get("description", "")[:200],
                         text_color="#bacbdb", wraplength=360, height=47,
                         font=("Segoe UI", 12), justify="left").pack(
                         anchor="w", fill="x", padx=18, pady=(5, 10))
            buttons = ctk.CTkFrame(card, fg_color="transparent")
            buttons.pack(fill="x", padx=16, pady=(0, 16))
            ctk.CTkButton(buttons, text="Get IPA" if not self._has_store_download(app)
                          else "Downloaded",
                          fg_color=STORE_BLUE, hover_color="#3062cb", height=37,
                          command=lambda item=app: self._store_download(item)).pack(side="left")
            ctk.CTkButton(buttons, text="Details", height=37, width=90,
                          fg_color="#23374f", hover_color="#304c65",
                          command=lambda item=app: self._store_app_details(item)).pack(
                          side="left", padx=8)

    def _store_app_details(self, app):
        window = ctk.CTkToplevel(self)
        window.title(app["name"] + " · ItamarOS Store")
        window.geometry("520x470")
        window.configure(fg_color="#0e1e32")
        window.transient(self)
        ctk.CTkLabel(window, text=app["name"], font=("Segoe UI", 26, "bold")).pack(
            anchor="w", padx=24, pady=(23, 3))
        ctk.CTkLabel(window, text="Verified ItamarOS Official" if app["official"]
                     else "Unverified Community Source",
                     text_color="#60b4ff" if app["official"] else "#f4ac64").pack(anchor="w", padx=24)
        for label, value in [
            ("Developer", app.get("developer", "")),
            ("Category", app.get("category", "")),
            ("Version", app.get("version", "")),
            ("Bundle ID", app.get("bundle_id", "")),
            ("Source", app.get("source_name", "")),
        ]:
            ctk.CTkLabel(window, text=f"{label}: {value}",
                         anchor="w", text_color="#c8d8ee", wraplength=470).pack(
                         fill="x", padx=24, pady=4)
        ctk.CTkLabel(window, text=app.get("description", ""),
                     wraplength=460, justify="left", text_color=STORE_MUTED).pack(
                     anchor="w", padx=24, pady=17)
        ctk.CTkLabel(window,
                     text="Downloading is not installation. Most preview apps are unsigned "
                          "and require authorized signing and compatible Apple provisioning.",
                     wraplength=460, justify="left",
                     text_color="#f0bf79").pack(anchor="w", padx=24, pady=10)
        ctk.CTkButton(window, text="Download IPA", fg_color=STORE_BLUE, height=40,
                      command=lambda: self._store_download(app)).pack(fill="x", padx=24, pady=8)

    def _store_download(self, app):
        if not app["official"] and not messagebox.askyesno(
            "Third-party app source",
            "This is an unverified Community Source. Only download apps "
            "from publishers you trust.\n\nContinue downloading " + app["name"] + "?"
        ):
            return
        def completed(result):
            path, signed = result
            self.status.configure(text=app["name"] + " saved to " + str(path))
            self._render_store_cards()
            messagebox.showinfo(
                "IPA Downloaded",
                f"{app['name']} was downloaded to:\n{path}\n\n"
                + ("A signature structure exists, but Apple's device service must "
                   "verify the certificate and provisioning before installation."
                   if signed else "This IPA is unsigned. Sign with an authorized certificate "
                   "before using a supported iPhone installation method.")
            )
        self._run(lambda: self.store_sources.download(app), completed)

    def _render_sources(self):
        self._section("Sources", "The official ItamarOS source is built in and cannot be removed.")
        official = self._card(self.content)
        official.pack(fill="x", padx=7, pady=9)
        ctk.CTkLabel(official, text="✔  ItamarOS Official · Verified Source",
                     text_color="#67b5ff", font=("Segoe UI", 16, "bold")).pack(
                     anchor="w", padx=18, pady=(15, 3))
        ctk.CTkLabel(official,
                     text="All first-party apps: BrowserOS, ItamarCut, Voice Recorder, "
                          "Screen Balance, Authenticator, ItamarOS Installer and games.",
                     text_color=STORE_MUTED, wraplength=760,
                     justify="left").pack(anchor="w", padx=18, pady=(0, 15))
        for source in self.store_sources.sources:
            item = self._card(self.content)
            item.pack(fill="x", padx=7, pady=7)
            row = ctk.CTkFrame(item, fg_color="transparent")
            row.pack(fill="x", padx=17, pady=(13, 3))
            ctk.CTkLabel(row, text="COMMUNITY  ·  " + source["name"],
                         font=("Segoe UI", 14, "bold"),
                         text_color="#f0bc7c").pack(side="left")
            buttons = ctk.CTkFrame(row, fg_color="transparent")
            buttons.pack(side="right")
            ctk.CTkButton(buttons, text="Disable" if source["enabled"] else "Enable",
                          command=lambda src=source:self._toggle_source(src),
                          width=80).pack(side="left", padx=4)
            ctk.CTkButton(buttons, text="Remove", fg_color="#8b404c",
                          command=lambda src=source:self._remove_source(src),
                          width=80).pack(side="left", padx=4)
            ctk.CTkLabel(item, text=source["url"], text_color=STORE_MUTED,
                         wraplength=760, justify="left").pack(anchor="w", padx=18, pady=(3, 14))
        ctk.CTkButton(self.content, text="+ Add HTTPS Community Source", height=44,
                      fg_color=STORE_BLUE, command=self._add_source_dialog).pack(
                      anchor="w", padx=11, pady=(16, 9))
        ctk.CTkLabel(self.content,
                     text="Community sources are not reviewed by ItamarOS. Their IPAs "
                          "are validated for format and Bundle ID, not guaranteed safe. "
                          "No P12 passwords or signing keys are shared with sources.",
                     text_color=STORE_MUTED, wraplength=810,
                     justify="left").pack(anchor="w", padx=12, pady=7)

    def _add_source_dialog(self):
        value = ctk.CTkInputDialog(
            text="Enter the public HTTPS address of an ItamarOS-compatible JSON source:",
            title="Add Community Source").get_input()
        if not value:
            return
        if not messagebox.askyesno("Trust this source?",
                                   "This catalog is outside the official ItamarOS source. "
                                   "Only add sources you trust. Continue?"):
            return
        def complete(_):
            self._refresh_store()
            self.show_store("Sources")
        self._run(lambda: self.store_sources.add(value), complete)

    def _remove_source(self, source):
        if messagebox.askyesno("Remove Community Source",
                               "Remove " + source["name"] + " from your catalog?"):
            self.store_sources.remove(source["id"])
            self._refresh_store()
            self.show_store("Sources")

    def _toggle_source(self, source):
        self.store_sources.set_enabled(source["id"], not source["enabled"])
        self._refresh_store()
        self.show_store("Sources")
