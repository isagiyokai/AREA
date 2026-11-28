import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import Feed from "@/components/feed";
import CommunityMembershipButton from "@/components/community-membership-button";
export const dynamic="force-dynamic";
type Community={id:string;name:string;slug:string;description:string;created_by:string;created_at:string;creator:{username:string;display_name:string}|{username:string;display_name:string}[]|null};
type Post={id:string;content:string;created_at:string;author_id:string;quoted_post_id:string|null;profiles:{username:string;display_name:string;area_class:string|null}[];quoted_post?:{id:string;content:string;created_at:string;author_id:string;profiles:{username:string;display_name:string;area_class:string|null}[]}|null};
export default async function CommunityPage({params}:{params:Promise<{slug:string}>}){
 const {slug}=await params;const supabase=await createClient();let userId:string|null=null;
 if(supabase){const {data:{user}}=await supabase.auth.getUser();userId=user?.id??null;}
 if(!supabase)notFound();
 const {data:raw}=await supabase.from("area_communities").select("id,name,slug,description,created_by,created_at,creator:profiles!area_communities_created_by_fkey(username,display_name)").eq("slug",slug).maybeSingle();
 if(!raw)notFound();const community=raw as unknown as Community;
 const {data:communityCounts}=await supabase.rpc("get_area_community_counts");const memberCount=Number((communityCounts??[]).find(row=>row.community_id===community.id)?.member_count??0);let isMember=false;let role:string|null=null;
 if(userId){const {data:membership}=await supabase.from("area_community_members").select("role").eq("community_id",community.id).eq("user_id",userId).maybeSingle();isMember=!!membership;role=membership?.role??null;}
 let blockedUserIds:string[]=[];if(userId){const {data:blocks}=await supabase.from("user_blocks").select("blocked_user_id").eq("user_id",userId);blockedUserIds=(blocks??[]).map(x=>x.blocked_user_id);}
 const {data:postRows}=await supabase.from("posts").select("id,content,created_at,author_id,quoted_post_id,profiles!posts_author_id_fkey(username,display_name,area_class)").eq("community_id",community.id).order("created_at",{ascending:false}).limit(40);
 let posts=(postRows??[]).filter(p=>!blockedUserIds.includes(p.author_id)) as unknown as Post[];
 const quoteIds=Array.from(new Set(posts.flatMap(p=>p.quoted_post_id?[p.quoted_post_id]:[])));
 if(quoteIds.length){const {data:quotes}=await supabase.from("posts").select("id,content,created_at,author_id,profiles!posts_author_id_fkey(username,display_name,area_class)").in("id",quoteIds);const map=new Map((quotes??[]).map(q=>[q.id,q]));posts=posts.map(p=>({...p,quoted_post:p.quoted_post_id?map.get(p.quoted_post_id)??null:null}));}
 const creator=Array.isArray(community.creator)?community.creator[0]??null:community.creator;
 return <main className="shell society-shell"><header className="top"><Link href="/" className="brand">AREA<span>.</span></Link><nav className="nav"><Link href="/">The street</Link><Link href="/gbas-gbos">Gbas Gbos</Link><Link href="/explore">Explore</Link><Link className="nav-current" href="/society">Society</Link></nav><div className="top-actions"><Link className="account-link" href={userId?"/account":"/login"}>{userId?"My account":"Sign in"}</Link></div></header>
 <section className="society-community-masthead"><Link className="society-back" href="/society">← All communities</Link><span className="eyebrow">AREA / SOCIETY / {community.slug.toUpperCase()}</span><h1>{community.name}</h1><p>{community.description||"A place for citizens who share this interest."}</p><div className="society-community-meta"><span>{memberCount.toLocaleString("en-NG")} MEMBERS</span><span>Founded by {creator?.display_name||creator?.username||"AREA citizen"}</span><span>/{community.slug}</span></div><CommunityMembershipButton communityId={community.id} isMember={isMember} isOwner={role==="owner"} signedIn={!!userId}/></section>
 <div className="section-rule"><span>COMMUNITY CONVERSATION</span><span>{isMember?"MEMBER ACCESS":"PUBLIC PREVIEW"}</span></div>
 {!isMember&&<div className="society-join-note"><strong>You're looking at the public side of this corner.</strong><p>Join the community to publish, reply and take part in its conversations.</p></div>}
 <section className="society-community-feed"><Feed initialPosts={posts} initialFollowingPosts={[]} signedIn={!!userId&&isMember} currentUserId={!!userId&&isMember?userId:null} blockedUserIds={blockedUserIds} loadFallback={false} communityId={community.id} streamTitle={community.name} emptyMessage="The conversation hasn't started yet. Be the first to bring something to the table."/></section>
 <footer className="site-footer"><span>AREA / SOCIETY</span><span>Different corners. One society.</span><Link href="/society">All communities ↗</Link></footer></main>;
}