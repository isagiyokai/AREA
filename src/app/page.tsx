import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import Feed from "@/components/feed";

export const dynamic = "force-dynamic";
type FeedPost={id:string;content:string;created_at:string;author_id:string;quoted_post_id:string|null;profiles:{username:string;display_name:string;area_class:string}[];quoted_post?:{id:string;content:string;created_at:string;author_id:string;profiles:{username:string;display_name:string;area_class:string}[]}|null};

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
  if(user){const {data:blocks}=await supabase.from("user_blocks").select("blocked_user_id").eq("user_id",user.id);blockedUserIds=(blocks??[]).map(row=>row.blocked_user_id);}
  const blockedSet=new Set(blockedUserIds);
  const {data:postData,error:postError}=await supabase.from("posts").select("id,content,created_at,author_id,quoted_post_id,profiles!posts_author_id_fkey(username,display_name,area_class)").order("created_at",{ascending:false}).limit(40);
  if(postError)console.error("AREA street feed query failed:",postError.message);
  if(postData)posts=postData.filter(post=>!blockedSet.has(post.author_id)) as typeof posts;
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
   const {data:circleData}=await supabase.from("posts").select("id,content,created_at,author_id,quoted_post_id,profiles!posts_author_id_fkey(username,display_name,area_class)").in("author_id",circleAuthors).order("created_at",{ascending:false}).limit(40);
   if(circleData)followingPosts=circleData.filter(post=>!blockedSet.has(post.author_id)) as typeof posts;
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
    <Link href="/leaderboard">Leaderboard</Link>
    {signedIn&&<Link href="/bookmarks">Saved</Link>}{signedIn&&<Link href="/messages">Messages</Link>}{signedIn&&<Link href="/wallet">AC Wallet</Link>}
    <span className="nav-muted">Market <small>soon</small></span>
    <span className="nav-muted">Territories <small>soon</small></span>
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
     <Link className="rail-link" href="/leaderboard"><span>04</span> Street leaderboard</Link>
     {signedIn&&<Link className="rail-link" href="/bookmarks"><span>04</span> Saved posts</Link>}{signedIn&&<Link className="rail-link" href="/messages"><span>05</span> Private messages</Link>}{signedIn&&<Link className="rail-link" href="/wallet"><span>06</span> AC Wallet</Link>}
     <div className="rail-link rail-soon"><span>03</span> AREA Market <small>SOON</small></div>
     <div className="rail-link rail-soon"><span>04</span> Territories <small>SOON</small></div>
     <div className="rail-link rail-soon"><span>05</span> Society <small>SOON</small></div>
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