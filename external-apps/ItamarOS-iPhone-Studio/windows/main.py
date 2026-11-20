"""ItamarOS iPhone Studio — modern Windows desktop UI."""
import json
import os
import shutil
import subprocess
import threading
from pathlib import Path
import tkinter as tk
from tkinter import filedialog, messagebox
import customtkinter as ctk

ctk.set_appearance_mode("dark")
ctk.set_default_color_theme("blue")
BG="#090E1B"
PANEL="#121B2D"
PANEL2="#1A2740"
BLUE="#4C8DFF"
MUTED="#9BAAC5"
WHITE="#F3F7FF"
CONFIG=Path(os.getenv("APPDATA",str(Path.home()))) / "ItamarOS" / "iPhoneStudio" / "settings.json"
DEFAULT_BACKUP=str(Path.home()/"Documents"/"ItamarOS iPhone Studio"/"Backups")

def load_settings():
    try:
        return json.loads(CONFIG.read_text(encoding="utf-8"))
    except (OSError,ValueError):
        return {"backup_enabled":True,"backup_path":DEFAULT_BACKUP}

def run_tool(*args):
    try:
        return subprocess.run(args,capture_output=True,text=True,timeout=15,check=False)
    except (OSError,subprocess.TimeoutExpired) as exc:
        return str(exc)

class Studio(ctk.CTk):
    def __init__(self):
        super().__init__(fg_color=BG)
        self.title("ItamarOS iPhone Studio")
        self.geometry("1060x700")
        self.minsize(860,590)
        self.settings=load_settings()
        self.sidebar=ctk.CTkFrame(self,width=224,corner_radius=0,fg_color="#0E1626")
        self.sidebar.pack(side="left",fill="y")
        self.sidebar.pack_propagate(False)
        ctk.CTkLabel(self.sidebar,text="◈  ItamarOS",font=ctk.CTkFont(size=23,weight="bold"),text_color=WHITE).pack(anchor="w",padx=23,pady=(34,5))
        ctk.CTkLabel(self.sidebar,text="iPHONE STUDIO",font=ctk.CTkFont(size=11,weight="bold"),text_color=BLUE).pack(anchor="w",padx=25,pady=(0,35))
        self.nav={}
        for title in ["Dashboard","Device Tools","Jailbreak & Wallpapers","Backup Settings","About"]:
            btn=ctk.CTkButton(self.sidebar,text="   "+title,anchor="w",height=45,corner_radius=12,fg_color="transparent",hover_color=PANEL2,text_color=MUTED,command=lambda t=title:self.show(t))
            btn.pack(fill="x",padx=13,pady=4)
            self.nav[title]=btn
        ctk.CTkLabel(self.sidebar,text="●  Local desktop mode",text_color="#67D9B0",font=ctk.CTkFont(size=12)).pack(side="bottom",pady=26)
        self.main=ctk.CTkScrollableFrame(self,fg_color=BG,corner_radius=0)
        self.main.pack(side="right",fill="both",expand=True)
        self.show("Dashboard")

    def clear(self):
        for child in self.main.winfo_children():
            child.destroy()

    def label(self,parent,text,size=14,color=WHITE,bold=False):
        return ctk.CTkLabel(parent,text=text,font=ctk.CTkFont(size=size,weight="bold" if bold else "normal"),text_color=color,anchor="w",justify="left")

    def card(self,parent):
        frame=ctk.CTkFrame(parent,fg_color=PANEL,corner_radius=19,border_width=1,border_color="#25334C")
        frame.pack(fill="x",pady=9)
        return frame

    def heading(self,title,subtitle):
        self.label(self.main,title,30,WHITE,True).pack(fill="x",padx=27,pady=(30,3))
        self.label(self.main,subtitle,13,MUTED).pack(fill="x",padx=28,pady=(0,17))

    def show(self,page):
        self.clear()
        for name,button in self.nav.items():
            button.configure(fg_color=PANEL2 if name==page else "transparent",text_color=WHITE if name==page else MUTED)
        if page=="Dashboard":self.dashboard()
        elif page=="Device Tools":self.device_tools()
        elif page=="Jailbreak & Wallpapers":self.jailbreak_wallpapers()
        elif page=="Backup Settings":self.backup_settings()
        else:self.about()

    def action(self,parent,title,command):
        return ctk.CTkButton(parent,text=title,command=command,height=40,corner_radius=11,fg_color=BLUE,hover_color="#3674D9")

    def dashboard(self):
        self.heading("Device Dashboard","Manage your iPhone with a clean, secure workspace.")
        device=self.card(self.main)
        self.label(device,"◉  DEVICE CONNECTION",12,BLUE,True).pack(anchor="w",padx=23,pady=(20,8))
        self.device_title=self.label(device,"iPhone not detected yet",23,WHITE,True)
        self.device_title.pack(anchor="w",padx=23)
        self.label(device,"Connect via USB and tap Trust on your iPhone.",13,MUTED).pack(anchor="w",padx=23,pady=(5,17))
        self.action(device,"Detect iPhone",self.detect).pack(anchor="w",padx=23,pady=(0,20))
        card=self.card(self.main)
        self.label(card,"Quick Actions",20,WHITE,True).pack(anchor="w",padx=22,pady=(18,10))
        row=ctk.CTkFrame(card,fg_color="transparent")
        row.pack(fill="x",padx=20,pady=(0,20))
        for title,command in [("USB Drivers",self.service),("Inspect IPSW",self.ipsw),("Install Signed IPA",self.install_ipa),("Backup Settings",lambda:self.show("Backup Settings"))]:
            ctk.CTkButton(row,text=title,command=command,fg_color=PANEL2,hover_color="#2C4164",corner_radius=12,height=54).pack(side="left",expand=True,fill="x",padx=4)
        self.log_panel()
        self.log("Ready. Windows USB detection is available without ideviceinfo; detailed device data is optional.")

    def log_panel(self):
        card=self.card(self.main)
        self.label(card,"Activity Log",17,WHITE,True).pack(anchor="w",padx=20,pady=(15,7))
        self.logbox=ctk.CTkTextbox(card,height=125,fg_color="#0B1220",text_color="#C8D8F4",corner_radius=12)
        self.logbox.pack(fill="x",padx=20,pady=(0,19))

    def log(self,message):
        if hasattr(self,"logbox") and self.logbox.winfo_exists():
            self.logbox.insert("end",message+"\n")
            self.logbox.see("end")

    def device_tools(self):
        self.heading("Device Tools","Check drivers and inspect firmware safely.")
        card=self.card(self.main)
        for text,cmd in [("Detect connected iPhone",self.detect),("Check Apple Mobile Device Service",self.service),("Choose IPSW file (inspection only)",self.ipsw),("Install signed IPA (USB)",self.install_ipa)]:
            self.action(card,text,cmd).pack(fill="x",padx=20,pady=9)
        self.label(card,"Firmware restore and jailbreak are not implemented. IPA installation requires ideviceinstaller and a valid signature.",12,MUTED).pack(padx=20,pady=(9,20))
        self.log_panel()

    def jailbreak_wallpapers(self):
        import webbrowser
        self.heading("Jailbreak & Wallpapers", "Compatibility information and official tools.")
        card = self.card(self.main)
        self.label(card, "Jailbreak compatibility", 20, WHITE, True).pack(anchor="w", padx=22, pady=(20, 8))
        self.label(card, "palera1n: checkm8 devices (A8–A11), including iPhone 6s through iPhone X.\n"
                   "iPhone 13 is not supported by palera1n. Exact firmware compatibility must be verified.",
                   13, MUTED).pack(anchor="w", padx=22, pady=(0, 12))
        self.action(card, "Official palera1n project",
                    lambda: webbrowser.open("https://github.com/palera1n/palera1n")).pack(anchor="w", padx=22, pady=(0, 20))
        card2 = self.card(self.main)
        self.label(card2, "TENDIES wallpapers", 20, WHITE, True).pack(anchor="w", padx=22, pady=(20, 8))
        self.label(card2, "TendiesWallpaper and GoldenNugget offer wallpaper customization on some\n"
                   "iOS versions without a full jailbreak. Compatibility varies by version.",
                   13, MUTED).pack(anchor="w", padx=22, pady=(0, 12))
        self.action(card2, "TENDIES application guide",
                    lambda: webbrowser.open("https://tendieswallpaper.com/application")).pack(anchor="w", padx=22, pady=(0, 20))
        self.label(self.main, "No jailbreak or wallpaper changes are executed by this page. Back up your device before system modifications.",
                   12, MUTED).pack(anchor="w", padx=20, pady=12)

    def backup_settings(self):
        self.heading("Backup Settings","Choose where future local backups should be stored.")
        card=self.card(self.main)
        self.backup_var=tk.BooleanVar(value=self.settings.get("backup_enabled",True))
        ctk.CTkSwitch(card,text="Enable local backups",variable=self.backup_var,progress_color=BLUE).pack(anchor="w",padx=22,pady=(24,16))
        self.label(card,"Backup folder",13,MUTED).pack(anchor="w",padx=22)
        self.path_var=tk.StringVar(value=self.settings.get("backup_path",DEFAULT_BACKUP))
        ctk.CTkEntry(card,textvariable=self.path_var,height=42,corner_radius=11).pack(fill="x",padx=22,pady=9)
        self.action(card,"Browse folder",self.choose_folder).pack(anchor="w",padx=22,pady=6)
        self.action(card,"Save preferences",self.persist).pack(anchor="w",padx=22,pady=(9,15))
        self.label(card,"These preferences are saved, but backup execution is not implemented yet.",12,MUTED).pack(anchor="w",padx=22,pady=(0,22))
        info=self.card(self.main)
        self.label(info,"☁  iCloud Backup Recommended",18,WHITE,True).pack(anchor="w",padx=22,pady=(18,5))
        self.label(info,"Settings → Apple Account → iCloud → iCloud Backup → Back Up Now",13,MUTED).pack(anchor="w",padx=22,pady=(0,18))

    def about(self):
        self.heading("About","ItamarOS iPhone Studio • Windows prototype")
        card=self.card(self.main)
        self.label(card,"Version 0.2 • Premium UI",20,WHITE,True).pack(anchor="w",padx=22,pady=(20,8))
        self.label(card,"A device-management prototype. No jailbreak, IPA signing, firmware restore or backup execution is available yet.",13,MUTED).pack(anchor="w",padx=22,pady=(0,20))

    def detect(self):
        self.log("Checking connected Apple devices...")
        def work():
            # PowerShell can enumerate Plug and Play devices using Windows' own
            # device registry, without requiring the libimobiledevice CLI.
            ps = (
                "$devices = @(Get-PnpDevice -PresentOnly -ErrorAction Stop | "
                "Where-Object { $_.InstanceId -match 'VID_05AC' -and "
                "($_.FriendlyName -match 'iPhone|iPad|Apple Mobile Device' -or "
                "$_.Class -match 'WPD|USB|PortableDevices') }); "
                "$devices | Select-Object -First 8 FriendlyName,Status,Class | ConvertTo-Json -Compress"
            )
            response = run_tool("powershell.exe", "-NoProfile", "-NonInteractive", "-Command", ps)
            devices = []
            error = ""
            if hasattr(response, "returncode") and response.returncode == 0:
                try:
                    parsed = json.loads(response.stdout) if response.stdout.strip() else []
                    devices = parsed if isinstance(parsed, list) else [parsed]
                except ValueError:
                    error = "Windows returned an unreadable device list."
            else:
                error = (response.stderr.strip() if hasattr(response, "stderr") else str(response))[:400]
            exe = shutil.which("ideviceinfo")
            detail = ""
            if exe:
                result = run_tool(exe, "-k", "ProductType")
                if hasattr(result, "returncode") and result.returncode == 0:
                    detail = result.stdout.strip()
            def update():
                if devices:
                    names = [str(d.get("FriendlyName") or "Apple USB Device") for d in devices]
                    self.device_title.configure(text=names[0])
                    self.log("Windows detected Apple USB hardware: " + ", ".join(names))
                    if detail:
                        self.log("Device model identifier: " + detail)
                    else:
                        self.log("USB detected; detailed model/iOS information requires a paired device API or ideviceinfo.")
                elif detail:
                    self.device_title.configure(text=detail)
                    self.log("Device model identifier: " + detail)
                else:
                    self.device_title.configure(text="iPhone not detected yet")
                    self.log("No Apple USB device found by Windows PnP. Check cable, Trust prompt and Apple Mobile Device driver.")
                    if error:
                        self.log("Windows device query: " + error)
            self.after(0, update)
        threading.Thread(target=work, daemon=True).start()

    def service(self):
        def work():
            out=run_tool("sc","query","Apple Mobile Device Service")
            result=(out.stdout.strip() if hasattr(out,"stdout") else str(out)) or "Apple Mobile Device Service not found."
            self.after(0,lambda:self.log(result[:1400]))
        threading.Thread(target=work,daemon=True).start()

    def install_ipa(self):
        path=filedialog.askopenfilename(filetypes=[("iOS App Package","*.ipa")])
        if not path:
            return
        exe=shutil.which("ideviceinstaller")
        if not exe:
            messagebox.showerror("Missing installer","Install a compatible ideviceinstaller CLI and Apple Mobile Device drivers first.")
            return
        if not messagebox.askyesno("Install signed IPA","Install the selected IPA on your connected, trusted iPhone? The IPA must be signed for this device."):
            return
        self.log("Installing signed IPA: "+Path(path).name)
        def work():
            try:
                result=subprocess.run([exe,"-i",path],capture_output=True,text=True,timeout=180,check=False)
                output=(result.stdout+"\\n"+result.stderr).strip()
                status="Install completed." if result.returncode==0 else "Install failed (exit code "+str(result.returncode)+")."
            except (OSError,subprocess.TimeoutExpired) as exc:
                status="Install failed."
                output=str(exc)
            self.after(0,lambda:self.log(status+"\\n"+output[-1600:]))
        threading.Thread(target=work,daemon=True).start()

    def ipsw(self):
        path=filedialog.askopenfilename(filetypes=[("iOS Firmware","*.ipsw")])
        if path:
            self.log("Selected: "+Path(path).name)
            messagebox.showinfo("Inspection only","No restore or downgrade will be performed. Apple signing has not been checked.")

    def choose_folder(self):
        folder=filedialog.askdirectory()
        if folder:self.path_var.set(folder)

    def persist(self):
        self.settings={"backup_enabled":self.backup_var.get(),"backup_path":self.path_var.get()}
        CONFIG.parent.mkdir(parents=True,exist_ok=True)
        CONFIG.write_text(json.dumps(self.settings,indent=2),encoding="utf-8")
        messagebox.showinfo("Settings saved","Backup preferences saved. Backup execution is not implemented.")

if __name__=="__main__":
    Studio().mainloop()
