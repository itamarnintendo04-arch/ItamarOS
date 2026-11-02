#!/usr/bin/env node
/**
 * Apply ItamarOS's reviewed authentication email HTML templates.
 * Default: DRY RUN (prints template names, DOES NOT access the network).
 * Apply: SUPABASE_ACCESS_TOKEN=<secret> node apply.mjs --apply
 *
 * Requires an owner's personal access token with permission to manage project
 * authentication settings. DO NOT put tokens in Git, browser code, or messages.
 * Do not use a service_role key here; the Management API needs an account PAT.
 *
 * Security notifications remain disabled unless explicitly opted in with
 * --enable-security-notices (requires --apply).
 */
import {readFile} from "node:fs/promises";

const types=[
 "confirmation","invite","magic_link","recovery","email_change","reauthentication",
 "password_changed_notification","email_changed_notification","phone_changed_notification",
 "identity_linked_notification","identity_unlinked_notification",
 "mfa_factor_enrolled_notification","mfa_factor_unenrolled_notification"
];
const notifications=types.filter(x=>x.endsWith("_notification"));
const subjects=JSON.parse(await readFile(new URL("./subjects.json",import.meta.url),"utf8"));
const config={};
for(const type of types){
 const html=await readFile(new URL("./"+type+".html",import.meta.url),"utf8");
 if(!html.includes("<!doctype html>")||!html.includes("Itamar")||
   (type==="reauthentication"&&!html.includes("{{ .Token }}"))||
   (["confirmation","invite","recovery","magic_link","email_change"].includes(type)&&
    !html.includes("{{ .ConfirmationURL }}"))){
  throw Error("Template validation failed: "+type);
 }
 if(!subjects[type])throw Error("Missing email subject for "+type);
 config["mailer_subjects_"+type]=subjects[type];
 config["mailer_templates_"+type+"_content"]=html;
}
const enable=process.argv.includes("--enable-security-notices");
const apply=process.argv.includes("--apply");
if(enable&&!apply)throw Error("--enable-security-notices requires --apply");
if(enable)for(const type of notifications){
 config["mailer_notifications_"+type.replace(/_notification$/,"")+"_enabled"]=true;
}
if(!apply){
 console.log("ItamarOS Email Templates — DRY RUN");
 console.log("Verified",types.length,"HTML templates and subjects.");
 console.log("Files:",types.join(", "));
 console.log("To apply: set SUPABASE_ACCESS_TOKEN in your local shell, then run:");
 console.log("node messaging/email-templates/apply.mjs --apply");
 console.log("Optional: add --enable-security-notices after reviewing message volume.");
 process.exit(0);
}
const token=process.env.SUPABASE_ACCESS_TOKEN;
const project=process.env.SUPABASE_PROJECT_REF||"slqjkysinhfkqjoigfuz";
if(!token || token.length<12)throw Error("Missing SUPABASE_ACCESS_TOKEN; never commit or print it.");
if(!/^[a-z0-9]{20}$/.test(project))throw Error("Invalid project reference");
const response=await fetch("https://api.supabase.com/v1/projects/"+project+"/config/auth",{
 method:"PATCH",
 headers:{"authorization":"Bearer "+token,"content-type":"application/json"},
 body:JSON.stringify(config)
});
if(!response.ok){
 const error=await response.text();
 throw Error("Template update failed: HTTP "+response.status+
    "; confirm access rights and template config. "+
    error.slice(0,200).replace(/(?:sbp_|sb_secret_|Bearer )\S+/g,"[redacted]"));
}
console.log("Applied",types.length,"ItamarOS templates to project",project);
console.log(enable?"Security notifications were enabled.":"Security notification enablement was left unchanged.");
console.log("Test delivery through a real address you control before launch.");
