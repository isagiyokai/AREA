import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import ProfileEditor from "@/components/profile-editor";

type Notification = {
 id:string;
 notification_type:string;
 message:string;
 actor_id:string|null;
 post_id:string|null;
 created_at:string;
 read_at:string|null;
};

export default async function Account(){
 const supabase=await createClient();
 if(!supabase)redirect("/login");
 const {data:{user}}=await supabase.auth.getUser();
 if(!user)redirect("/login");
 const [{data:profile},{data:notifications},{data:isAdmin}]=await Promise.all([
  supabase.from("profiles").select("username,display_name,bio,area_class,created_at").eq("id",user.id).single(),
  supabase.from("notifications").select("id,notification_type,message,actor_id,post_id,created_at,read_at").eq("recipient_id",user.id).order("created_at",{ascending:false}).limit(30),
  supabase.rpc("is_area_admin_profile",{p_user_id:user.id})
 ]);
 const items=(notifications??[]) as Notification[];
 const actorIds=[...new Set(items.flatMap(n=>n.actor_id?[n.actor_id]:[]))];
 const {data:actors}=actorIds.length?await supabase.from("profiles").select("id,username").in("id",actorIds):{data:[] as {id:string;username:string}[]};
 const actorNames=new Map((actors??[]).map(a=>[a.id,a.username]));
 const unread=items.filter(n=>!n.read_at).length;
 return <main className="shell account-shell">
  <header className="top"><Link href="/" className="brand">AREA<span>.</span></Link><div className="account-top-links"><Link href="/">The street ↗</Link><Link href="/bookmarks">Saved posts ↗</Link><Link href="/explore">Explore ↗</Link><Link href="/leaderboard">Leaderboard ↗</Link><Link href="/messages">Messages ↗</Link><form action="/auth/signout" method="post"><button className="text-action" type="submit">Sign out</button></form></div></header>
  <section className="account-intro"><div className="eyebrow">{isAdmin?"AREA ADMIN":profile?.area_class?"Citizen file / "+profile.area_class.toUpperCase():"Citizen file"}</div><h1>{profile?.display_name||"AREA Citizen"}</h1><p>@{profile?.username||"citizen"} <span>·</span> Joined {profile?.created_at?new Date(profile.created_at).toLocaleDateString():"recently"}</p></section>
  <div className="account-grid">
   <div className="account-main"><ProfileEditor userId={user.id} initialDisplayName={profile?.display_name||""} initialUsername={profile?.username||""} initialBio={profile?.bio||""}/></div>
   <aside className="account-side"><span className="mini-label">YOUR PLACE IN AREA</span><div className="account-class">{isAdmin?"ADMIN":profile?.area_class?.toUpperCase()||"UNCLASSIFIED"}</div><p>Your name, your relationships and what you do here will shape your place in the street.</p><Link className="text-action" href="/leaderboard">View street standing ↗</Link><div className="account-stat"><span>NOTIFICATIONS</span><strong>{unread} unread</strong></div></aside>
  </div>
  <section className="panel account-panel notifications-panel">
   <div className="notifications-heading"><h2 className="heading">The postman</h2><span>{unread} unread</span></div>
   {!items.length?<p className="notice">Nothing in the post yet. Replies, quotes, mentions and Gbas Gbos callouts will show up here.</p>:
    <div className="notification-list">{items.map(n=><article className={n.read_at?"notification-item":"notification-item unread"} key={n.id}>
     <div className="notification-copy"><div className="notification-type">{n.notification_type==="argument_invitation"?"Gbas Gbos callout":n.notification_type.replaceAll("_"," ")}</div><p>{n.message}</p><time>{new Date(n.created_at).toLocaleString()}</time></div>
     <div className="notification-actions">{n.post_id&&<Link className="text-action" href={"/p/"+n.post_id}>Open conversation</Link>}{n.notification_type==="direct_message"&&n.actor_id&&actorNames.get(n.actor_id)&&<Link className="text-action" href={"/messages/"+encodeURIComponent(actorNames.get(n.actor_id)!)}>Open private chat</Link>}{!n.read_at&&<form action="/notifications/read" method="post"><input type="hidden" name="notification_id" value={n.id}/><button className="text-action" type="submit">Mark read</button></form>}</div>
    </article>)}</div>}
  </section>
 </main>;
}