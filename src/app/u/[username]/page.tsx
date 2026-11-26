import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import FollowButton from "@/components/follow-button";
import ReportCitizen from "@/components/report-citizen";
import BlockCitizen from "@/components/block-citizen";

type Profile={
 id:string;
 username:string;
 display_name:string;
 bio:string|null;
 area_class:string|null;
 created_at:string;
};

export const dynamic="force-dynamic";

export default async function CitizenPage({params}:{params:Promise<{username:string}>}){
 const {username}=await params;
 const supabase=await createClient();
 if(!supabase)notFound();
 const {data:profile}=await supabase.from("profiles")
  .select("id,username,display_name,bio,area_class,created_at")
  .eq("username",username.toLowerCase())
  .maybeSingle();
 if(!profile)notFound();
 const {data:{user}}=await supabase.auth.getUser();
 const {data:isAdmin}=await supabase.rpc("is_area_admin_profile",{p_user_id:profile.id});
 const [{data:posts,count},{count:followers},{count:following},{data:followRow},{data:standing}]=await Promise.all([
  supabase.from("posts")
  .select("id,content,created_at",{count:"exact"})
  .eq("author_id",profile.id)
  .order("created_at",{ascending:false})
  .limit(40),
  supabase.from("follows").select("follower_id",{count:"exact",head:true}).eq("followed_id",profile.id),
  supabase.from("follows").select("followed_id",{count:"exact",head:true}).eq("follower_id",profile.id),
  user&&user.id!==profile.id?supabase.from("follows").select("follower_id").eq("follower_id",user.id).eq("followed_id",profile.id).maybeSingle():Promise.resolve({data:null,error:null}),
  supabase.from("citizen_standing").select("standing_points,standing_title,standing_rank,posts,replies,replies_received,followers,yard_points,yard_title,yard_rank,callouts_started,callouts_received,yard_replies").eq("user_id",profile.id).maybeSingle()
 ]);
 const citizen=profile as Profile;
 return <main className="shell citizen-shell">
  <header className="top"><Link href="/" className="brand">AREA<span>.</span></Link><div className="account-top-links"><Link href="/">← The street</Link><Link href="/account">My account</Link></div></header>
  <section className="citizen-cover">
   <span className="mini-label">{isAdmin?"AREA ADMIN":citizen.area_class?"CITIZEN / "+citizen.area_class.toUpperCase():"CITIZEN"}</span>
   <div className="citizen-identity">
    <div className="citizen-avatar">{citizen.display_name.slice(0,1).toUpperCase()}</div>
    <div><h1>{citizen.display_name} {isAdmin&&<span className="admin-profile-tag">ADMIN</span>}</h1><p>@{citizen.username}</p></div>
   </div>
   <p className="citizen-bio">{citizen.bio||"No bio yet. Let the conversations do the talking."}</p>
   <div className="citizen-follow-row"><div className="citizen-meta"><span>IN AREA SINCE {new Date(citizen.created_at).toLocaleDateString("en-NG",{month:"short",year:"numeric"}).toUpperCase()}</span><span>{count??0} POSTS</span><span>{following??0} FOLLOWING</span><span>RANK #{standing?.standing_rank??"—"}</span></div><div className="citizen-actions">{user&&user.id!==citizen.id&&<Link className="btn primary" href={"/messages/"+encodeURIComponent(citizen.username)}>Message ↗</Link>}<FollowButton profileId={citizen.id} currentUserId={user?.id??null} initialFollowing={!!followRow} initialFollowers={followers??0}/>{user&&user.id!==citizen.id&&<ReportCitizen profileId={citizen.id} currentUserId={user.id}/>} {user&&user.id!==citizen.id&&<BlockCitizen profileId={citizen.id} currentUserId={user.id}/>}</div></div>
  </section>
  <section className="citizen-standing"><div><span className="mini-label">STREET STANDING</span><strong>{standing?.standing_title??"New voice"}</strong><p>{standing?.standing_points??0} participation points · #{standing?.standing_rank??"—"} on the street</p></div><div className="standing-breakdown"><span>{standing?.replies??0} replies made</span><span>{standing?.replies_received??0} replies received</span><span>{standing?.followers??0} followers</span></div><small>Participation measure, not a judgement of anyone’s worth or the quality of their opinions.</small><div className="yard-standing"><span className="mini-label">GBAS GBOS / YARD STANDING</span><strong>{standing?.yard_title??"New to the yard"}</strong><p>{standing?.yard_points??0} yard points · #{standing?.yard_rank??"—"} in Gbas Gbos</p><small>{standing?.callouts_started??0} callouts started · {standing?.callouts_received??0} received · {standing?.yard_replies??0} replies in the yard</small></div></section>
  <section className="citizen-activity">
   <div className="citizen-activity-head"><div><span className="mini-label">PUBLIC ACTIVITY</span><h2>What they've been saying</h2></div><span className="citizen-post-count">{count??0} total</span></div>
   {!posts?.length?<p className="notice">No posts yet. Everybody has a first word.</p>:posts.map(post=><article className="citizen-post" key={post.id}>
    <div className="citizen-post-date">{new Date(post.created_at).toLocaleString("en-NG",{dateStyle:"medium",timeStyle:"short"})}</div>
    <p>{post.content}</p>
    <Link href={"/p/"+post.id} className="text-action">View conversation ↗</Link>
   </article>)}
   {count&&count>40?<p className="notice">Showing the latest 40 posts.</p>:null}
  </section>
  <footer className="site-footer"><span>AREA © 2026</span><span>A Nigerian digital society.</span><Link href="/">Back to the street ↗</Link></footer>
 </main>;
}