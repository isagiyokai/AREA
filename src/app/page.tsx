import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import Feed from "@/components/feed";

export const dynamic = "force-dynamic";

export default async function Home() {
 const supabase=await createClient();
 let posts: Array<{id:string;content:string;created_at:string;author_id:string;profiles:{username:string;display_name:string;area_class:string}[]}>= [];
 let signedIn=false;
 let currentUserId:string|null=null;\n let unreadCount=0;
 if(supabase){
  const {data:{user}}=await supabase.auth.getUser();
  signedIn=!!user;
  currentUserId=user?.id??null;
  const [{data},unread]=await Promise.all([supabase.from("posts").select("id,content,created_at,author_id,profiles(username,display_name,area_class)").order("created_at",{ascending:false}).limit(40);
  if(data)posts=data as typeof posts;
 }
 return <main className="shell">
  <header className="top">
   <Link href="/" className="brand" aria-label="AREA home">AREA<span>.</span></Link>
   <nav className="nav" aria-label="Main navigation">
    <a className="nav-current" href="#feed">The street</a>
    <a href="#talking-points">Gbas Gbos</a>
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
     <a className="rail-link" href="#talking-points"><span>02</span> Gbas Gbos</a>
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

   <div className="feed-column">
    <Feed initialPosts={posts} signedIn={signedIn} currentUserId={currentUserId}/>
   </div>

   <aside className="right">
    <div className="talk-panel" id="talking-points">
     <div className="talk-heading"><span className="mini-label">OPEN QUESTIONS</span><span className="talk-count">PICK A SIDE</span></div>
     <h2>Wetin dey your mind?</h2>
     <a className="talk-item" href="#feed"><span>01 / FOOD</span><strong>Jollof rice: who really get am?</strong><small>Start the argument ↗</small></a>
     <a className="talk-item" href="#feed"><span>02 / EVERYDAY LIFE</span><strong>Soft life or hustle culture?</strong><small>Bring your own angle ↗</small></a>
     <a className="talk-item" href="#feed"><span>03 / CULTURE</span><strong>Which Nigerian slang needs to retire?</strong><small>Say your mind ↗</small></a>
    </div>
    <div className="right-note">
     <span className="mini-label">A SMALL REMINDER</span>
     <p>Talk your talk. Disagree well. You can always leave a conversation that has gone too far.</p>
    </div>
    <div className="right-signoff">Made of people.<br/>Not perfect people.</div>
   </aside>
  </section>

  <footer className="site-footer"><span>AREA © 2026</span><span>A Nigerian digital society.</span><Link href="/signup">Come inside ↗</Link></footer>
 </main>;
}