"use client";
import { useEffect, useState } from "react";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";

type Message={id:string;sender_id:string;recipient_id:string;body:string;created_at:string;read_at:string|null};
export default function DirectMessageThread({userId,recipientId,recipientName,recipientUsername,initialMessages}:{userId:string;recipientId:string;recipientName:string;recipientUsername:string;initialMessages:Message[]}){
 const [messages,setMessages]=useState(initialMessages),[draft,setDraft]=useState(""),[busy,setBusy]=useState(false),[error,setError]=useState("");
 useEffect(()=>{
  const supabase=createClient();
  const channel=supabase.channel("dm:"+[userId,recipientId].sort().join(":"))
   .on("postgres_changes",{event:"INSERT",schema:"public",table:"direct_messages",filter:"sender_id=eq."+recipientId},payload=>{
    const row=payload.new as Message;setMessages(current=>current.some(m=>m.id===row.id)?current:[...current,row].sort((a,b)=>a.created_at.localeCompare(b.created_at)));
   })
   .on("postgres_changes",{event:"INSERT",schema:"public",table:"direct_messages",filter:"sender_id=eq."+userId},payload=>{
    const row=payload.new as Message;if(row.recipient_id!==recipientId)return;setMessages(current=>current.some(m=>m.id===row.id)?current:[...current,row].sort((a,b)=>a.created_at.localeCompare(b.created_at)));
   }).subscribe();
  return()=>{void supabase.removeChannel(channel);};
 },[userId,recipientId]);
 async function send(e:React.FormEvent){e.preventDefault();const body=draft.trim();if(!body||busy)return;if(body.length>2000){setError("Keep it under 2,000 characters.");return;}setBusy(true);setError("");try{const supabase=createClient();const {data:{user}}=await supabase.auth.getUser();if(!user||user.id!==userId)throw new Error("Your session has changed. Sign in again.");const {data,error:insertError}=await supabase.from("direct_messages").insert({sender_id:userId,recipient_id:recipientId,body}).select("id,sender_id,recipient_id,body,created_at,read_at").single();if(insertError)throw insertError;setMessages(current=>current.some(m=>m.id===data.id)?current:[...current,data].sort((a,b)=>a.created_at.localeCompare(b.created_at)));setDraft("");}catch(err){setError(err instanceof Error?err.message:"Could not send this message.");}finally{setBusy(false);}}
 return <section className="dm-thread">
  <header className="dm-thread-head"><Link href="/messages" className="dm-back">← Inbox</Link><div><strong>{recipientName}</strong><span>@{recipientUsername}</span></div><Link href={"/u/"+encodeURIComponent(recipientUsername)} className="text-action">Profile ↗</Link></header>
  <div className="dm-message-list">{messages.length===0?<div className="dm-empty"><strong>First word is yours.</strong><p>Start the conversation. Keep it between you two.</p></div>:messages.map(message=><article key={message.id} className={"dm-bubble "+(message.sender_id===userId?"mine":"theirs")}><p>{message.body}</p><time>{new Date(message.created_at).toLocaleString("en-NG",{hour:"numeric",minute:"2-digit",day:"numeric",month:"short"})}</time></article>)}</div>
  <form className="dm-compose" onSubmit={send}><textarea maxLength={2000} value={draft} onChange={e=>setDraft(e.target.value)} placeholder={"Message "+recipientName+"…"} rows={2}/><div className="dm-compose-foot"><span>{draft.length}/2000 · Private conversation</span><button className="btn primary" disabled={busy||!draft.trim()}>{busy?"Sending…":"Send ↗"}</button></div>{error&&<p className="error">{error}</p>}</form>
 </section>;
}
