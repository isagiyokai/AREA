"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

type TopicPost={id:string;content:string;created_at:string;author_id:string;profiles:{username:string;display_name:string;area_class:string}|{username:string;display_name:string;area_class:string}[]|null;replyCount:number};
type Challenge={id:string;post_id:string;challenger_id:string;challenged_id:string;intensity:number;status:string;created_at:string;expires_at:string;posts:{id:string;content:string}|{id:string;content:string}[]|null;challenger:{username:string;display_name:string}|{username:string;display_name:string}[]|null;challenged:{username:string;display_name:string}|{username:string;display_name:string}[]|null};
const topics=[{tag:"FOOD & CULTURE",title:"Jollof rice: who really get am?",starter:"Settle this one: who really makes the best jollof rice, and why?"},{tag:"MONEY & EVERYDAY LIFE",title:"Soft life or hustle culture?",starter:"Is soft life a real option or just another thing people sell online?"},{tag:"NAIJA CULTURE",title:"Which slang needs to retire?",starter:"Which Nigerian slang has overstayed its welcome? Defend your nomination."},{tag:"RELATIONSHIPS",title:"Can friendship survive money matter?",starter:"Can a friendship survive lending money that never comes back?"},{tag:"FOOTBALL",title:"Club loyalty: love or suffering?",starter:"At what point does loyalty to your club become self-inflicted suffering?"},{tag:"SOCIETY",title:"What do people pretend not to notice?",starter:"What's one thing everybody knows is happening, but nobody wants to say out loud?"}];
const person=(v:Challenge["challenger"])=>Array.isArray(v)?v[0]:v;
const post=(v:Challenge["posts"])=>Array.isArray(v)?v[0]:v;
export default function GbasGbosBoard({initialPosts,initialChallenges,signedIn}:{initialPosts:TopicPost[];initialChallenges:Challenge[];signedIn:boolean}){
 const router=useRouter();const [draft,setDraft]=useState("");const [busy,setBusy]=useState(false);const [error,setError]=useState("");const [filter,setFilter]=useState<"all"|"active"|"pending">("all");
 async function start(text:string){setError("");if(!signedIn){router.push("/login");return;}const value=text.trim();if(value.length<3||value.length>500)return;setBusy(true);try{const sb=createClient();const {data:{user}}=await sb.auth.getUser();if(!user)throw new Error("Please sign in again.");const {data,error}=await sb.from("posts").insert({author_id:user.id,content:value}).select("id").single();if(error)throw error;router.push("/#post-"+data.id);router.refresh();}catch(e){setError(e instanceof Error?e.message:"Could not start this argument.");}finally{setBusy(false);}}
 const visibleChallenges=initialChallenges.filter(c=>filter==="all"||c.status===filter);
 return <main className="shell gbas-shell">
  <header className="top"><Link href="/" className="brand">AREA<span>.</span></Link><nav className="nav"><Link href="/">The street</Link><Link className="nav-current" href="/gbas-gbos">Gbas Gbos</Link></nav><div className="top-actions"><Link className="account-link" href={signedIn?"/account":"/login"}>{signedIn?"My account":"Sign in"}</Link><Link className="btn primary" href={signedIn?"/account":"/signup"}>{signedIn?"Your corner":"Join the street"}</Link></div></header>
  <section className="gbas-masthead"><div><span className="mini-label">AREA / THE ARGUMENT YARD</span><h1>Gbas <em>Gbos.</em></h1><p>Bring your point. Bring your receipts. Let the other person answer. Some gist no dey settle itself.</p></div><div className="gbas-stamp"><span>NO BE EVERY</span><strong>ARGUMENT</strong><span>NEED WINNER</span><b>GB / 001</b></div></section>
  <div className="gbas-rule"><span>THE YARD IS OPEN</span><span>CONSENT BEFORE ESCALATION · EXIT WHENEVER</span></div>
  <section className="gbas-grid">
   <div className="gbas-main">
    <section className="gbas-start"><div className="gbas-section-head"><div><span className="mini-label">START SOMETHING</span><h2>Wetin you wan settle?</h2></div><span className="gbas-index">01 / OPEN THE FLOOR</span></div><textarea value={draft} onChange={e=>setDraft(e.target.value)} maxLength={500} placeholder="Drop the take. Give people something to disagree with…"/><div className="gbas-compose-foot"><span>{draft.length}/500</span><button className="btn primary" disabled={busy||draft.trim().length<3} onClick={()=>void start(draft)}>{busy?"Posting…":"Start the argument ↗"}</button></div>{error&&<p className="error">{error}</p>}
     <div className="topic-strip"><span className="mini-label">NEED A SPARK?</span><div className="topic-chips">{topics.map(t=><button key={t.tag} type="button" onClick={()=>setDraft(t.starter)}>{t.tag}</button>)}</div></div>
    </section>
    <section className="gbas-section"><div className="gbas-section-head"><div><span className="mini-label">REAL CONVERSATIONS</span><h2>Arguments on the street</h2></div><span className="gbas-index">02 / JOIN IN</span></div>
     {!initialPosts.length?<div className="gbas-empty"><strong>The floor is yours.</strong><p>No arguments have started here yet. Be the first to put a topic on the table.</p></div>:<div className="gbas-post-list">{initialPosts.map((p,i)=><article className="gbas-post" key={p.id}><span className="gbas-post-number">{String(i+1).padStart(2,"0")}</span><div className="gbas-post-body"><div className="gbas-post-meta"><strong>{Array.isArray(p.profiles)?p.profiles[0]?.display_name:p.profiles?.display_name||"AREA Citizen"}</strong><span>@{(Array.isArray(p.profiles)?p.profiles[0]?.username:p.profiles?.username)||"citizen"}</span><span>· {new Date(p.created_at).toLocaleDateString("en-NG",{day:"numeric",month:"short"})}</span></div><p>{p.content}</p><div className="gbas-post-actions"><span>{p.replyCount} {p.replyCount===1?"reply":"replies"}</span><Link href={"/#post-"+p.id}>Enter conversation ↗</Link></div></div></article>)}</div>}
    </section>
   </div>
   <aside className="gbas-side">
    <section className="spar-board"><div className="gbas-section-head"><div><span className="mini-label">THE RING</span><h2>Sparring board</h2></div><span className="gbas-index">03</span></div><div className="spar-filters">{(["all","active","pending"] as const).map(f=><button type="button" key={f} aria-pressed={filter===f} onClick={()=>setFilter(f)}>{f==="all"?"All":f==="active"?"In play":"Awaiting"}</button>)}</div>
     {!visibleChallenges.length?<div className="spar-empty"><strong>Ring is quiet.</strong><p>When citizens challenge each other and both agree, their spar appears here.</p></div>:visibleChallenges.map(c=>{const a=person(c.challenger),b=person(c.challenged),p=post(c.posts);return <article className="spar-card" key={c.id}><div className="spar-card-top"><span>{c.status==="active"?"IN PLAY":"INVITATION SENT"}</span><b>{c.intensity===1?"BANTER":c.intensity===2?"HEATED":"FULL WAHALA"}</b></div><div className="spar-names">{a?.display_name||"Citizen"} <i>vs</i> {b?.display_name||"Citizen"}</div><p>{p?.content||"Conversation"}</p><Link href={"/#post-"+c.post_id}>View the exchange ↗</Link></article>;})}
    </section>
    <section className="gbas-rules"><span className="mini-label">THE HOUSE RULES</span><h2>Bring heat. Keep your head.</h2><ul><li>Banter is not blanket permission for abuse.</li><li>Both citizens must accept before a spar starts.</li><li>Higher intensity needs a fresh yes from both sides.</li><li>Either person can end an exchange.</li><li>No threats, doxxing, stalking or targeted harassment.</li></ul></section>
   </aside>
  </section>
  <footer className="site-footer"><span>AREA © 2026</span><span>Everybody get mouth. Everybody get matter.</span><Link href="/">Back to the street ↗</Link></footer>
 </main>;
}
