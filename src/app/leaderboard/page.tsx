import Link from "next/link";
import { createClient } from "@/lib/supabase/server";

export const dynamic="force-dynamic";

type Standing={user_id:string;username:string;display_name:string;area_class:string|null;standing_points:number;standing_title:string;standing_rank:number;posts:number;replies:number;replies_received:number;followers:number;yard_points:number;yard_title:string;yard_rank:number;callouts_started:number;callouts_received:number;yard_replies:number};

export default async function LeaderboardPage(){
 const supabase=await createClient();
 const {data}=supabase?await supabase.from("citizen_standing").select("user_id,username,display_name,area_class,standing_points,standing_title,standing_rank,posts,replies,replies_received,followers,yard_points,yard_title,yard_rank,callouts_started,callouts_received,yard_replies").order("standing_points",{ascending:false}).order("created_at",{ascending:true}).limit(100):{data:[]};
 const rows=(data??[]) as Standing[];
 return <main className="shell">
  <header className="top"><Link href="/" className="brand">AREA<span>.</span></Link><nav className="nav"><Link href="/">The street</Link><Link href="/gbas-gbos">Gbas Gbos</Link><Link href="/explore">Explore</Link><Link className="nav-current" href="/leaderboard">Leaderboard</Link></nav><div className="top-actions"><Link className="account-link" href="/account">My account</Link></div></header>
  <section className="leaderboard-intro"><span className="mini-label">AREA / STREET STANDING</span><h1>Names carry <em>weight.</em></h1><p>Street standing counts posts, replies, replies received and followers. Gbas Gbos standing counts callouts started or received and replies inside the yard. Neither score rewards insults, outrage or payment.</p></section>
  <section className="leaderboard-wrap"><div className="leaderboard-head"><span>THE STREET / TOP 100</span><span>{rows.length} CITIZENS WITH A PLACE</span></div>
   {!rows.length?<div className="dm-empty"><strong>The board is waiting.</strong><p>As citizens post, reply and build connections, their standing will appear here.</p></div>:rows.map((r,i)=><Link className="leaderboard-row" href={"/u/"+encodeURIComponent(r.username)} key={r.user_id}><span className="leaderboard-rank">#{i+1}</span><span className="leaderboard-citizen"><strong>{r.display_name}</strong><small>@{r.username} · {r.standing_title.toUpperCase()}</small></span><span className="leaderboard-score"><strong>{r.standing_points}</strong><small>STREET PTS</small><strong>{r.yard_points}</strong><small>YARD PTS · #{r.yard_rank}</small></span></Link>)}
  </section>
  <footer className="site-footer"><span>AREA © 2026</span><span>Participation is not a popularity contest.</span><Link href="/">Back to the street ↗</Link></footer>
 </main>;
}
