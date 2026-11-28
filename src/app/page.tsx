import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import Feed from "@/components/feed";

export const dynamic = "force-dynamic";
type FeedPost={id:string;content:string;created_at:string;author_id:string;quoted_post_id:string|null;profiles:{username:string;display_name:string;area_class:string|null}[];quoted_post?:{id:string;content:string;created_at:string;author_id:string;profiles:{username:string;display_name:string;area_class:string|null}[]}|null;reposted_by:{username:string;display_name:string;area_class:string|null}[]|null;reposted_at:string|null};
type RepostRow={post_id:string;user_id:string;created_at:string;profiles:{username:string;display_name:string;area_class:string|null}[]|{username:string;display_name:string;area_class:string|null}|null};
const profileOne=(v:RepostRow["profiles"])=>Array.isArray(v)?v[0]??null:v;

export default async function Home() {
 const supabase=await createClient();
 let posts: FeedPost[]=[];
 let followingPosts: FeedPost[]=[];
 let signedIn=false;
 let currentUserId:string|null=null;
 let blockedUserIds:string[]=[];
 let unreadCount=0;
 if(supabase){
  const {data:{user}}=await supabase.auth.getUser();
  signedIn=!!user;
  currentUserId=user?.id??null;
  if(user){
   const {data:isAreaAdmin}=await supabase.rpc("is_area_admin_profile",{p_user_id:user.id});
   if(!isAreaAdmin){
    const {data:entryProfile}=await supabase.from("profiles").select("area_entry_tier").eq("id",user.id).maybeSingle();
    if(!entryProfile?.area_entry_tier)redirect("/entry");
    const [{data:activeTerritory},{count:activeTerritoryCount}]=await Promise.all([
     supabase.from("agbero_memberships").select("id").eq("citizen_id",user.id).eq("status","inside").maybeSingle(),
     supabase.from("agbero_territories").select("id",{count:"exact",head:true}).eq("active",true)
    ]);
    if(!activeTerritory&&(activeTerritoryCount??0)>0)redirect("/territories");
   }
  }
  if(user){const {data:blocks}=await supabase.from("user_blocks").select("blocked_user_id").eq("user_id",user.id);blockedUserIds=(blocks??[]).map(row=>row.blocked_user_id);}
  const blockedSet=new Set(blockedUserIds);
  const {data:postData,error:postError}=await supabase.from("posts").select("id,content,created_at,author_id,quoted_post_id,profiles!posts_author_id_fkey(username,display_name,area_class)").is("community_id",null).order("created_at",{ascending:false}).limit(40);
  if(postError)console.error("AREA street feed query failed:",postError.message);
  if(postData)posts=postData.filter(post=>!blockedSet.has(post.author_id)).map(post=>({...post,reposted_by:null,reposted_at:null})) as typeof posts;
  const {data:streetRepostRows}=await supabase.from("post_reposts").select("post_id,user_id,created_at,profiles!post_reposts_user_id_fkey(username,display_name,area_class)").order("created_at",{ascending:false}).limit(30);
  const visibleStreetReposts=((streetRepostRows??[]) as unknown as RepostRow[]).filter(row=>!blockedSet.has(row.user_id));
  const streetRepostIds=Array.from(new Set(visibleStreetReposts.map(row=>row.post_id)));
  if(streetRepostIds.length){
   const {data:repostedPosts}=await supabase.from("posts").select("id,content,created_at,author_id,quoted_post_id,profiles!posts_author_id_fkey(username,display_name,area_class)").in("id",streetRepostIds).is("community_id",null);
   const byId=new Map(posts.map(post=>[post.id,post]));for(const post of (repostedPosts??[]) as unknown as FeedPost[]){if(!blockedSet.has(post.author_id)&&!byId.has(post.id))byId.set(post.id,{...post,reposted_by:null,reposted_at:null});}
   const latest=new Map<string,RepostRow>();for(const row of visibleStreetReposts){if(!latest.has(row.post_id))latest.set(row.post_id,row);}
   posts=[...byId.values()].map(post=>{const row=latest.get(post.id);return row?{...post,reposted_by:profileOne(row.profiles)?[profileOne(row.profiles)!]:null,reposted_at:row.created_at}:post;}).sort((a,b)=>Date.parse(b.reposted_at??b.created_at)-Date.parse(a.reposted_at??a.created_at)).slice(0,40);
  }
  const unreadQuery=user
   ?supabase.from("notifications").select("id",{count:"exact",head:true}).eq("recipient_id",user.id).is("read_at",null)
   :Promise.resolve({count:0,data:null,error:null});
  const followsQuery=user
   ?supabase.from("follows").select("followed_id").eq("follower_id",user.id)
   :Promise.resolve({data:[],error:null});
  const [unread,followRows]=await Promise.all([unreadQuery,followsQuery]);
  unreadCount=unread.count??0;
  if(user){
   const circleAuthors=[user.id,...(followRows.data??[]).map(row=>row.followed_id)];
   const {data:circleData}=await supabase.from("posts").select("id,content,created_at,author_id,quoted_post_id,profiles!posts_author_id_fkey(username,display_name,area_class)").in("author_id",circleAuthors).is("community_id",null).order("created_at",{ascending:false}).limit(40);
   if(circleData)followingPosts=circleData.filter(post=>!blockedSet.has(post.author_id)).map(post=>({...post,reposted_by:null,reposted_at:null})) as typeof posts;
   const {data:circleRepostRows}=await supabase.from("post_reposts").select("post_id,user_id,created_at,profiles!post_reposts_user_id_fkey(username,display_name,area_class)").in("user_id",circleAuthors).order("created_at",{ascending:false}).limit(30);
   const visibleCircleReposts=((circleRepostRows??[]) as unknown as RepostRow[]).filter(row=>!blockedSet.has(row.user_id));
   const circleRepostIds=Array.from(new Set(visibleCircleReposts.map(row=>row.post_id)));
   if(circleRepostIds.length){
    const {data:repostedPosts}=await supabase.from("posts").select("id,content,created_at,author_id,quoted_post_id,profiles!posts_author_id_fkey(username,display_name,area_class)").in("id",circleRepostIds).is("community_id",null);
    const byId=new Map(followingPosts.map(post=>[post.id,post]));for(const post of (repostedPosts??[]) as unknown as FeedPost[]){if(!blockedSet.has(post.author_id)&&!byId.has(post.id))byId.set(post.id,{...post,reposted_by:null,reposted_at:null});}
    const latest=new Map<string,RepostRow>();for(const row of visibleCircleReposts){if(!latest.has(row.post_id))latest.set(row.post_id,row);}
    followingPosts=[...byId.values()].map(post=>{const row=latest.get(post.id);return row?{...post,reposted_by:profileOne(row.profiles)?[profileOne(row.profiles)!]:null,reposted_at:row.created_at}:post;}).sort((a,b)=>Date.parse(b.reposted_at??b.created_at)-Date.parse(a.reposted_at??a.created_at)).slice(0,40);
   }
  }
  const quoteIds=Array.from(new Set([...posts,...followingPosts].flatMap(p=>p.quoted_post_id?[p.quoted_post_id]:[])));
  if(quoteIds.length){
   const {data:quoteRows}=await supabase.from("posts").select("id,content,created_at,author_id,profiles!posts_author_id_fkey(username,display_name,area_class)").in("id",quoteIds);
   const quoteMap=new Map((quoteRows??[]).map(q=>[q.id,q]));
   posts=posts.map(p=>({...p,quoted_post:p.quoted_post_id?quoteMap.get(p.quoted_post_id)??null:null}));
   followingPosts=followingPosts.map(p=>({...p,quoted_post:p.quoted_post_id?quoteMap.get(p.quoted_post_id)??null:null}));
  }
 }
 return <main className="shell">
  <header className="top">
   <Link href="/" className="brand" aria-label="AREA home">AREA<span>.</span></Link>
   <nav className="nav" aria-label="Main navigation">
    <a className="nav-current" href="#feed">The street</a>
    <Link href="/gbas-gbos">Gbas Gbos</Link>
    <Link href="/explore">Explore</Link>
    <Link href="/leaderboard">Leaderboard</Link><Link href="/wolves">Community court</Link>
    {signedIn&&<Link href="/bookmarks">Saved</Link>}{signedIn&&<Link href="/messages">Messages</Link>}{signedIn&&<Link href="/wallet">AC Wallet</Link>}
    <Link href="/market">Market</Link>
    <Link href="/territories">Territories</Link><Link href="/society">Society</Link><Link href="/events">Events</Link>
   </nav>
   <div className="top-actions">
    {signedIn?<Link href="/account" className="account-link">My account{unreadCount>0?<span className="nav-notice">{unreadCount>9?"9+":unreadCount}</span>:""} ↗</Link>:<Link href="/login" className="account-link">Sign in</Link>}
    <Link className="btn primary" href={signedIn?"/account":"/signup"}>{signedIn?"Your corner":"Join the street"}</Link>
   </div>
  </header>
  <section className="front-note">
   <div className="front-copy">
    <div className="eyebrow"><span className="live-dot"/> A Nigerian digital society</div>
    <h1>No be only you<br/>dey this <em>country.</em></h1>
    <p>One place for the gist, the arguments, the friendships and everything in between. Pull up. Your people dey here.</p>
   </div>
   <div className="front-aside">
    <span className="front-aside-label">THE AREA MOTTO</span>
    <p>Everybody get mouth.<br/>Everybody get matter.</p>
    <span className="front-aside-mark">AREA / 001</span>
   </div>
  </section>
  <div className="section-rule"><span>THE STREET</span><span>OPEN TO EVERYBODY</span></div>
  <section className="layout" id="feed">
   <aside className="left">
    <div className="rail-block">
     <h2 className="rail-title">Find your way</h2>
     <a className="rail-link rail-active" href="#feed"><span>01</span> The street</a>
     <Link className="rail-link" href="/gbas-gbos"><span>02</span> Gbas Gbos</Link>
     <Link className="rail-link" href="/explore"><span>03</span> Explore</Link>
     <Link className="rail-link" href="/leaderboard"><span>04</span> Street leaderboard</Link><Link className="rail-link" href="/wolves"><span>07</span> Community court</Link>
     {signedIn&&<Link className="rail-link" href="/bookmarks"><span>04</span> Saved posts</Link>}{signedIn&&<Link className="rail-link" href="/messages"><span>05</span> Private messages</Link>}{signedIn&&<Link className="rail-link" href="/wallet"><span>06</span> AC Wallet</Link>}
     <Link className="rail-link" href="/market"><span>08</span> AREA Market</Link>
     <Link className="rail-link" href="/territories"><span>09</span> Territories</Link>
     <Link className="rail-link" href="/society"><span>10</span> Society</Link>
     <Link className="rail-link" href="/events"><span>11</span> Events</Link>
    </div>
    <div className="rail-block start-block">
     <span className="mini-label">NEW AROUND HERE?</span>
     <h2>Start from somewhere.</h2>
     <p>Enter through SLUMS for free. Build your name, meet your people and find your own way up.</p>
     <span className="entry-stamp">SLUMS · FREE ENTRY</span>
    </div>
   </aside>
   <div className="feed-column"><Feed initialPosts={posts} initialFollowingPosts={followingPosts} signedIn={signedIn} currentUserId={currentUserId} blockedUserIds={blockedUserIds}/></div>
   <aside className="right">
    <div className="talk-panel" id="talking-points">
     <div className="talk-heading"><span className="mini-label">GBAS GBOS</span><Link className="talk-count" href="/gbas-gbos">ENTER THE RING ↗</Link></div>
     <h2>Wetin dey your mind?</h2>
     <Link className="talk-item" href="/gbas-gbos"><span>01 / FOOD</span><strong>Jollof rice: who really get am?</strong><small>Take it to Gbas Gbos ↗</small></Link>
     <Link className="talk-item" href="/gbas-gbos"><span>02 / EVERYDAY LIFE</span><strong>Soft life or hustle culture?</strong><small>Take it to Gbas Gbos ↗</small></Link>
     <Link className="talk-item" href="/gbas-gbos"><span>03 / CULTURE</span><strong>Which Nigerian slang needs to retire?</strong><small>Take it to Gbas Gbos ↗</small></Link>
    </div>
    <div className="right-note"><span className="mini-label">A SMALL REMINDER</span><p>Talk your talk. Disagree well. You can always leave a conversation that has gone too far.</p></div>
    <div className="right-signoff">Made of people.<br/>Not perfect people.</div>
   </aside>
  </section>
  <footer className="site-footer"><span>AREA © 2026</span><span>A Nigerian digital society.</span><Link href="/signup">Come inside ↗</Link></footer>
 </main>;
}