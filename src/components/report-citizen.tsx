"use client";
import { useState } from "react";
import { createClient } from "@/lib/supabase/client";

export default function ReportCitizen({profileId,currentUserId}:{profileId:string;currentUserId:string|null}){
 const [open,setOpen]=useState(false),[reason,setReason]=useState("harassment"),[details,setDetails]=useState(""),[busy,setBusy]=useState(false),[message,setMessage]=useState("");
 if(!currentUserId||currentUserId===profileId)return null;
 async function submit(e:React.FormEvent<HTMLFormElement>){
  e.preventDefault();setBusy(true);setMessage("");
  const sb=createClient();
  const {error}=await sb.from("content_reports").insert({reporter_id:currentUserId,target_type:"profile",target_id:profileId,reason,details:details.trim()||null});
  setBusy(false);
  if(error){setMessage(error.message);return;}
  setMessage("Report sent to the moderation desk.");setDetails("");setOpen(false);
 }
 return <div className="profile-report">
  <button type="button" className="text-action" onClick={()=>{setOpen(v=>!v);setMessage("");}}>Report citizen</button>
  {open&&<form className="post-report-form" onSubmit={submit}>
   <strong>Tell the moderation desk</strong>
   <select value={reason} onChange={e=>setReason(e.target.value)}><option value="threats">Threats</option><option value="harassment">Targeted harassment</option><option value="doxxing">Doxxing / private information</option><option value="spam">Spam</option><option value="impersonation">Impersonation</option><option value="other">Other</option></select>
   <textarea value={details} maxLength={1000} onChange={e=>setDetails(e.target.value)} placeholder="Add context (optional)…" rows={2}/>
   <div><button type="button" className="text-action" onClick={()=>setOpen(false)}>Cancel</button><button className="btn primary" disabled={busy}>{busy?"Sending…":"Send report"}</button></div>
  </form>}
  {message&&<small role="status">{message}</small>}
 </div>;
}
