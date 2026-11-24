import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

type Notification = {
 id:string;
 notification_type:string;
 message:string;
 post_id:string|null;
 created_at:string;
 read_at:string|null;
};

export default async function Account(){
 const supabase=await createClient();
 if(!supabase)redirect("/login");
 const {data:{user}}=await supabase.auth.getUser();
 if(!user)redirect("/login");
 const [{data:profile},{data:notifications}]=await Promise.all([
  supabase.from("profiles").select("username,display_name,bio,area_class,created_at").eq("id",user.id).single(),
  supabase.from("notifications").select("id,notification_type,message,post_id,created_at,read_at").eq("recipient_id",user.id).order("created_at",{ascending:false}).limit(30)
 ]);
 const items=(notifications??[]) as Notification[];
 const unread=items.filter(n=>!n.read_at).length;
 return <main className="shell">
  <header className="top"><Link href="/" className="brand">AREA<span>.</span></Link><Link href="/" className="btn">The street</Link></header>
  <section className="hero"><div className="eyebrow">Citizen profile</div><h1>{profile?.display_name||"AREA Citizen"}</h1><p>@{profile?.username||"citizen"} · <span className="green">{(profile?.area_class||"slums").toUpperCase()}</span></p></section>
  <section className="panel account-panel"><h2 className="heading">Your details</h2><p className="muted">{profile?.bio||"Your story in AREA is just beginning."}</p><p className="notice">Joined {profile?.created_at?new Date(profile.created_at).toLocaleDateString():"recently"}</p><form action="/auth/signout" method="post"><button className="btn">Sign out</button></form></section>
  <section className="panel account-panel notifications-panel">
   <div className="notifications-heading"><h2 className="heading">Your notifications</h2><span>{unread} unread</span></div>
   {!items.length?<p className="notice">No notifications yet. Your AREA will let you know when someone challenges you or responds to your spar.</p>:
    <div className="notification-list">{items.map(n=><article className={n.read_at?"notification-item":"notification-item unread"} key={n.id}>
     <div className="notification-copy"><div className="notification-type">{n.notification_type.replaceAll("_"," ")}</div><p>{n.message}</p><time>{new Date(n.created_at).toLocaleString()}</time></div>
     <div className="notification-actions">{n.post_id&&<Link className="text-action" href={"/#post-"+n.post_id}>Open conversation</Link>}{!n.read_at&&<form action="/notifications/read" method="post"><input type="hidden" name="notification_id" value={n.id}/><button className="text-action" type="submit">Mark read</button></form>}</div>
    </article>)}</div>}
  </section>
 </main>;
}