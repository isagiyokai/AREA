import Link from "next/link";
import { notFound,redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import DirectMessageThread from "@/components/direct-message-thread";
export const dynamic="force-dynamic";
type Message={id:string;sender_id:string;recipient_id:string;body:string;created_at:string;read_at:string|null};
export default async function DirectConversation({params}:{params:Promise<{username:string}>}){
 const {username}=await params;const supabase=await createClient();if(!supabase)redirect("/login");
 const {data:{user}}=await supabase.auth.getUser();if(!user)redirect("/login");
 const {data:recipient}=await supabase.from("profiles").select("id,username,display_name").eq("username",username.toLowerCase()).maybeSingle();
 if(!recipient||recipient.id===user.id)notFound();
 const pair="and(sender_id.eq."+user.id+",recipient_id.eq."+recipient.id+"),and(sender_id.eq."+recipient.id+",recipient_id.eq."+user.id+")";
 const {data,error}=await supabase.from("direct_messages").select("id,sender_id,recipient_id,body,created_at,read_at").or(pair).order("created_at",{ascending:true}).limit(300);
 if(error)console.error("AREA private conversation load failed:",error.message);
 await supabase.from("direct_messages").update({read_at:new Date().toISOString()}).eq("sender_id",recipient.id).eq("recipient_id",user.id).is("read_at",null);
 return <main className="shell messages-shell"><header className="top"><Link href="/" className="brand">AREA<span>.</span></Link><div className="account-top-links"><Link href="/messages">Inbox</Link><Link href="/account">My account</Link></div></header><section className="messages-intro compact"><span className="eyebrow">AREA / DIRECT LINE</span><h1>Private conversation.</h1><p>Between you and @{recipient.username}.</p></section><DirectMessageThread userId={user.id} recipientId={recipient.id} recipientName={recipient.display_name} recipientUsername={recipient.username} initialMessages={(data??[]) as Message[]}/><footer className="site-footer"><span>AREA © 2026</span><span>Private means private.</span><Link href="/messages">Back to inbox ↗</Link></footer></main>;
}
