"use client";

import { useState } from "react";
import { createClient } from "@/lib/supabase/client";

export default function ProfileEditor({
 userId,
 initialDisplayName,
 initialUsername,
 initialBio
}:{
 userId:string;
 initialDisplayName:string;
 initialUsername:string;
 initialBio:string;
}){
 const [displayName,setDisplayName]=useState(initialDisplayName);
 const [username,setUsername]=useState(initialUsername);
 const [bio,setBio]=useState(initialBio);
 const [busy,setBusy]=useState(false);
 const [error,setError]=useState("");
 const [saved,setSaved]=useState(false);

 async function save(e:React.FormEvent<HTMLFormElement>){
  e.preventDefault();
  setError("");
  setSaved(false);
  const cleanName=displayName.trim();
  const cleanUsername=username.trim().toLowerCase();
  const cleanBio=bio.trim();
  if(cleanName.length<2||cleanName.length>40){setError("Your display name must be between 2 and 40 characters.");return;}
  if(!/^[a-z0-9_]{3,24}$/.test(cleanUsername)){setError("Username must be 3–24 characters using letters, numbers or underscores.");return;}
  if(cleanBio.length>160){setError("Your bio must be 160 characters or fewer.");return;}
  setBusy(true);
  try{
   const supabase=createClient();
   const {error}=await supabase.from("profiles").update({
    display_name:cleanName,
    username:cleanUsername,
    bio:cleanBio
   }).eq("id",userId);
   if(error)throw error;
   setDisplayName(cleanName);
   setUsername(cleanUsername);
   setBio(cleanBio);
   setSaved(true);
  }catch(e){
   const message=e instanceof Error?e.message:"Could not save your profile.";
   setError(message.toLowerCase().includes("duplicate")||message.toLowerCase().includes("unique")
    ?"That username is already taken. Try another one."
    :message);
  }finally{setBusy(false);}
 }

 return <form className="profile-editor" onSubmit={save}>
  <div className="profile-editor-head"><div><span className="mini-label">YOUR PUBLIC DETAILS</span><h2 className="heading">Make yourself known.</h2></div><span className="profile-edit-mark">EDIT / 01</span></div>
  <label className="profile-field"><span>Display name</span><input value={displayName} onChange={e=>{setDisplayName(e.target.value);setSaved(false);}} maxLength={40} required/></label>
  <label className="profile-field"><span>Username</span><div className="username-input"><span>@</span><input value={username} onChange={e=>{setUsername(e.target.value.toLowerCase().replace(/[^a-z0-9_]/g,""));setSaved(false);}} minLength={3} maxLength={24} required/></div></label>
  <label className="profile-field"><span>Bio <small>{bio.length}/160</small></span><textarea value={bio} onChange={e=>{setBio(e.target.value);setSaved(false);}} maxLength={160} rows={3} placeholder="A little about yourself. Your own words."/></label>
  {error&&<p className="error" role="alert">{error}</p>}
  {saved&&<p className="success" role="status">Your details have been updated.</p>}
  <div className="profile-editor-foot"><span className="notice">Your username is how people find you.</span><button className="btn primary" disabled={busy}>{busy?"Saving…":"Save changes"}</button></div>
 </form>;
}