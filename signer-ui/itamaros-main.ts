import { signIpa } from "./zsign-api";
import type { OutputFile } from "./types";

const form = document.querySelector<HTMLFormElement>("#sign-form")!;
const ipaInput = document.querySelector<HTMLInputElement>("#ipa")!;
const certInput = document.querySelector<HTMLInputElement>("#identity")!;
const profileInput = document.querySelector<HTMLInputElement>("#profile")!;
const passwordInput = document.querySelector<HTMLInputElement>("#password")!;
const signButton = document.querySelector<HTMLButtonElement>("#sign")!;
const progress = document.querySelector<HTMLProgressElement>("#progress")!;
const status = document.querySelector<HTMLParagraphElement>("#status")!;
const log = document.querySelector<HTMLPreElement>("#log")!;
const resultPanel = document.querySelector<HTMLElement>("#result")!;
const download = document.querySelector<HTMLAnchorElement>("#download")!;

let signedFileUrl: string | null = null;
const MAX_IPA = 500 * 1024 * 1024;

function validate(file: File | undefined, extension: RegExp, label: string): File {
  if (!file) throw new Error("Choose " + label + ".");
  if (!extension.test(file.name)) throw new Error("Invalid " + label + " filename.");
  if (file.size < 1) throw new Error("Empty " + label + " file.");
  return file;
}

function appendLog(value: string, password: string) {
  // Some native tools may echo CLI arguments. Never display the certificate password.
  const text = password ? value.split(password).join("[REDACTED]") : value;
  const lines = (log.textContent || "").split("\n");
  lines.push(text.slice(0, 700));
  log.textContent = lines.slice(-110).join("\n");
}

function resetResult() {
  resultPanel.classList.add("hidden");
  if (signedFileUrl) URL.revokeObjectURL(signedFileUrl);
  signedFileUrl = null;
  download.removeAttribute("href");
}

function setBusy(value: boolean) {
  signButton.disabled = value;
  ipaInput.disabled = value;
  certInput.disabled = value;
  profileInput.disabled = value;
  passwordInput.disabled = value;
  progress.classList.toggle("hidden", !value);
}

function outputBlob(item: OutputFile): Blob {
  if (item.data instanceof Blob) return item.data;
  return new Blob([item.data], { type: "application/octet-stream" });
}

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (signButton.disabled) return;

  resetResult();
  log.textContent = "";
  progress.removeAttribute("value");
  progress.max = 100;
  const password = passwordInput.value;

  try {
    const ipa = validate(ipaInput.files?.[0], /\.ipa$/i, "a .ipa");
    const p12 = validate(certInput.files?.[0], /\.(p12|pfx)$/i, "a .p12 certificate");
    const profile = validate(profileInput.files?.[0], /\.mobileprovision$/i, "a .mobileprovision file");
    if (ipa.size > MAX_IPA) {
      throw new Error("This IPA is too large for this browser signer (500 MB maximum).");
    }
    if (!globalThis.Worker || !globalThis.WebAssembly) {
      throw new Error("Your browser does not support the required local WebAssembly worker.");
    }

    setBusy(true);
    status.textContent = "Signing locally on this device. Do not close the page.";
    const outputName = ipa.name.replace(/\.ipa$/i, "") + "-signed.ipa";
    const response = await signIpa(
      { ipa, p12, profiles: [profile], password, outputName, zipLevel: 6 },
      {
        storageMode: "memory",
        onLog: (line) => appendLog(line, password),
        onProgress: (step) => {
          if (step.total > 0) {
            progress.value = Math.min(100, Math.round((step.completed / step.total) * 100));
          } else {
            progress.removeAttribute("value");
          }
        }
      }
    );

    if (response.exitCode !== 0) {
      throw new Error("Signer exited with code " + response.exitCode + ". Review the signing log.");
    }
    const signed = response.outputs.find((item) => item.name.toLowerCase().endsWith(".ipa"));
    if (!signed) {
      throw new Error("No signed IPA was returned. The signer may not support this package.");
    }
    signedFileUrl = URL.createObjectURL(outputBlob(signed));
    download.href = signedFileUrl;
    download.download = outputName;
    resultPanel.classList.remove("hidden");
    status.textContent = "Signing finished in your browser. Download the resulting IPA.";
    appendLog("Signing completed. Output kept in this browser until the page is closed.", "");
  } catch (error) {
    status.textContent = error instanceof Error ? "Signing failed: " + error.message : "Signing failed.";
    appendLog(status.textContent, password);
  } finally {
    // The P12 password is never persisted; clear the visible form promptly.
    passwordInput.value = "";
    setBusy(false);
  }
});

window.addEventListener("pagehide", resetResult);
