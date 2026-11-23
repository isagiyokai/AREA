import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import Feed from "@/components/feed";

export const dynamic = "force-dynamic";

export default async function Home() {
  const supabase = await createClient();
  let posts: Array<{id:string;content:string;created_at:string;author_id:string;profiles:{username:string;display_name:string;area_class:string}[]}> = [];
  let signedIn = false;
  if (supabase) {
    const { data: { user } } = await supabase.auth.getUser();
    signedIn = !!user;
    const { data } = await supabase.from("posts").select("id,content,created_at,author_id,profiles(username,display_name,area_class)").order("created_at",{ascending:false}).limit(40);
    if (data) posts = data as typeof posts;
  }
  return <main className="shell">
    <header className="top"><Link href="/" className="brand">AREA<span>.</span></Link><nav className="nav"><a href="#feed">The street</a><a href="#trending">Trending</a>{signedIn?<Link href="/account">My account</Link>:<Link href="/login">Sign in</Link>}</nav><Link className="btn primary" href={signedIn?"/account":"/signup"}>{signedIn?"Your profile":"Join AREA"}</Link></header>
    <section className="hero"><div className="eyebrow">One country. One digital society.</div><h1>Your people.<br/><span className="green">Your AREA.</span></h1><p>Where the gist travels, the banter is alive, and everybody has a place. Pull up a chair. The street is talking.</p></section>
    <section className="layout" id="feed">
      <aside className="left"><div className="panel"><h2 className="heading">Your AREA</h2><div className="side">The street <b>LIVE</b></div><div className="side">Communities <b>SOON</b></div><div className="side">Territories <b>SOON</b></div><div className="side">Leaderboard <b>SOON</b></div></div><div className="panel"><h2 className="heading">Choose your lane</h2><p className="muted" style={{fontSize:12,lineHeight:1.7}}>Start in SLUMS. Build your name. Make your moves. Your story in AREA starts with you.</p><span className="tag">SLUMS · FREE ENTRY</span></div></aside>
      <div><div className="panel"><Feed initialPosts={posts} signedIn={signedIn}/></div></div>
      <aside className="right"><div className="panel" id="trending"><h2 className="heading">The gist</h2><div className="trend"><small>01 · NIGERIA</small><b>What's happening today?</b><small>Conversations are warming up</small></div><div className="trend"><small>02 · CULTURE</small><b>Which city has the best jollof?</b><small>Somebody is about to be dragged</small></div><div className="trend"><small>03 · STREET</small><b>Soft life or hustle?</b><small>The debate never ends</small></div></div><div className="panel"><h2 className="heading">AREA is just opening</h2><p className="muted" style={{fontSize:12,lineHeight:1.7}}>Bring your people. Start conversations. Help shape the culture of this place.</p><Link className="btn primary" href="/signup">Become a citizen</Link></div></aside>
    </section>
    <footer className="muted" style={{padding:"30px 0",fontSize:11}}>AREA · A Nigerian digital society · Built for the people.</footer>
  </main>;
}
