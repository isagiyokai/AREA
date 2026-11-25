import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
export const dynamic="force-dynamic";
type Message={id:string;sender_id:string;recipient_id:string;body:string;created_at:string;read_at:string|null};
type Profile={id:string;username:string;display_name:string;area_class:string};
export default async function MessagesInbox(){
 const supabase=await createClient();if(!supabase)redirect("/login");
 const {data:{user}}=await supabase.auth.getUser();if(!user)redirect("/login");
 const {data}=await supabase.from("direct_messages").select("id,sender_id,recipient_id,body,created_at,read_at").or("sender_id.eq."+user.id+",recipient_id.eq."+user.id).order("created_at",{ascending:false}).limit(300);
 const rows=(data??[]) as Message[];const latest=new Map<string,{message:Message;unread:number}>();
 for(const m of rows){const peer=m.sender_id===user.id?m.recipient_id:m.sender_id;const current=latest.get(peer);if(!current)latest.set(peer,{message:m,unread:m.recipient_id===user.id&&!m.read_at?1:0});else if(m.recipient_id===user.id&&!m.read_at)current.unread++;}
 const ids=[...latest.keys()];const {data:profiles}=ids.length?await supabase.from("profiles").select("id,username,display_name,area_class").in("id",ids):{data:[] as Profile[]};
 const people=new Map((profiles??[]).map(p=>[p.id,p as Profile]));
 return <main className="shell messages-shell"><header className="top"><Link href="/" className="brand">AREA<span>.</span></Link><nav className="nav"><Link href="/">The street</Link><Link href="/gbas-gbos">Gbas Gbos</Link><Link href="/explore">Explore</Link></nav><div className="top-actions"><Link href="/account" className="account-link">My account ↗</Link></div></header>
 <section className="messages-intro"><span className="eyebrow">AREA / PRIVATE LINE</span><h1>Behind the gist.</h1><p>One-on-one conversations, away from the public timeline.</p></section>
 <section className="dm-inbox"><div className="dm-inbox-head"><h2>Your conversations</h2><span>{latest.size} {latest.size===1?"thread":"threads"}</span></div>{!latest.size?<div className="dm-empty"><strong>Your inbox is quiet.</strong><p>Visit a citizen's profile and start a conversation. Some things are better said directly.</p><Link href="/explore" className="btn primary">Find a citizen ↗</Link></div>:<div className="dm-inbox-list">{[...latest.entries()].sort((a,b)=>b[1].message.created_at.localeCompare(a[1].message.created_at)).map(([id,item])=>{const person=people.get(id);if(!person)return null;return <Link className="dm-inbox-row" href={"/messages/"+encodeURIComponent(person.username)} key={id}><span className="dm-avatar">{person.display_name.slice(0,1).toUpperCase()}</span><span className="dm-inbox-copy"><strong>{person.display_name}</strong><small>@{person.username} · {new Date(item.message.created_at).toLocaleString("en-NG",{dateStyle:"medium",timeStyle:"short"})}</small><p>{item.message.sender_id===user.id?"You: ":""}{item.message.body}</p></span>{item.unread>0&&<b className="dm-unread">{item.unread>9?"9+":item.unread}</b>}<span className="dm-arrow">↗</span></Link>;})}</div>}</section>
 <footer className="site-footer"><span>AREA © 2026</span><span>Private means private.</span><Link href="/">Back to the street ↗</Link></footer></main>;
}
