#!/usr/bin/env python3
"""Only performs a session power action after a separate, explicit confirmation."""
import subprocess
import tkinter as tk
from tkinter import messagebox

root = tk.Tk()
root.title("ItamarOS • Power")
root.geometry("345x260")
root.resizable(False, False)
root.configure(background="#101a35")

title = tk.Label(root, text="ItamarOS Power", fg="#daf5ff",
                 bg="#101a35", font=("Sans", 17, "bold"))
title.pack(pady=(22, 14))

def action(label, operation):
    if messagebox.askyesno("Confirm " + label,
                           "Do you want to " + label.lower() + " this computer?"):
        root.destroy()
        subprocess.run(["/usr/bin/systemctl", operation], check=False)

for label, cmd in [("Sleep", "suspend"), ("Restart", "reboot"), ("Shut Down", "poweroff")]:
    tk.Button(root, text=label, width=22,
              command=lambda l=label, c=cmd: action(l, c)).pack(pady=5)

tk.Button(root, text="Cancel", width=22, command=root.destroy).pack(pady=(8, 0))
root.mainloop()
