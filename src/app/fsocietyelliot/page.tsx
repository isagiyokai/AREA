import Link from "next/link";
import { notFound,redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import AdminReportActions from "@/components/admin-report-actions";
export const dynamic="force-dynamic";
type Citizen={id:string;username:string;display_name:string;area_class:string;created_at:string};
type Post={id:string;content:string;created_at:string;username:string;display_name:string};
type Report={id:string;target_type:string;target_id:string;reason:string;details:string|null;status:string;created_at:string;reporter_username:string;target_username:string|null;target_post_id:string|null};
type Overview={citizens:number;posts:number;replies:number;messages:number;open_reports:number;recent_citizens:Citizen[];recent_posts:Post[];reports:Report[]};
export default async function OwnerConsole(){
 const supabase=await createClient();if(!supabase)redirect("/login");
 const {data:{user}}=await supabase.auth.getUser();if(!user)redirect("/login");
 const {data:allowed,error:authError}=await supabase.rpc("is_area_admin");
 if(authError||allowed!==true)notFound();
 const {data,error}=await supabase.rpc("get_area_admin_overview");
 if(error||!data)throw new Error("Could not load the AREA owner console.");
 const overview=data as Overview;
 return <main className="shell admin-shell"><header className="top"><Link href="/" className="brand">AREA<span>.</span></Link><div className="account-top-links"><span className="admin-secure-label">OWNER ACCESS</span><Link href="/">View the street ↗</Link><Link href="/account">My account</Link></div></header>
 <section className="admin-masthead"><span className="eyebrow">FSOCIETY / OWNER CONSOLE</span><h1>Welcome back,<br/><em>architect.</em></h1><p>One view of the society. Real numbers, real people, no theatre.</p><span className="admin-console-mark">AREA / ROOT ACCESS</span></section>
 <section className="admin-metrics"><article><span>CITIZENS</span><strong>{overview.citizens}</strong></article><article><span>PUBLIC POSTS</span><strong>{overview.posts}</strong></article><article><span>REPLIES</span><strong>{overview.replies}</strong></article><article><span>PRIVATE MESSAGES</span><strong>{overview.messages}</strong></article><article className={overview.open_reports?"metric-alert":""}><span>OPEN REPORTS</span><strong>{overview.open_reports}</strong></article></section>
 <section className="admin-columns"><div className="admin-main"><section className="admin-panel"><div className="admin-panel-head"><div><span className="mini-label">MODERATION DESK</span><h2>Reports needing attention</h2></div><span>{overview.reports.length} in queue</span></div>{!overview.reports.length?<p className="notice">No open reports. The queue is clear.</p>:overview.reports.map(r=><article className="admin-report" key={r.id}><div className="admin-report-top"><strong>{r.reason.replaceAll("_"," ")}</strong><span>{r.target_type} · {r.status.replaceAll("_"," ")}</span></div><p>{r.details||"No additional details supplied."}</p><small>Reported by @{r.reporter_username} · {new Date(r.created_at).toLocaleString("en-NG")}</small>{r.target_type==="post"&&<Link className="text-action" href={"/p/"+r.target_id}>Open reported post ↗</Link>}{r.target_type==="profile"&&<Link className="text-action" href={"/u/"+encodeURIComponent(r.target_username||"")}>Open reported profile ↗</Link>}{r.target_type==="reply"&&r.target_post_id&&<Link className="text-action" href={"/p/"+r.target_post_id}>Open reported reply ↗</Link>}<AdminReportActions reportId={r.id} status={r.status}/></article>)}</section>
 <section className="admin-panel"><div className="admin-panel-head"><div><span className="mini-label">THE STREET</span><h2>Latest public posts</h2></div><Link href="/">Open feed ↗</Link></div>{overview.recent_posts.map(p=><article className="admin-post" key={p.id}><div><strong>{p.display_name} <small>@{p.username}</small></strong><time>{new Date(p.created_at).toLocaleString("en-NG")}</time></div><p>{p.content}</p><Link href={"/p/"+p.id}>Open conversation ↗</Link></article>)}</section></div>
 <aside className="admin-side"><section className="admin-panel"><div className="admin-panel-head"><div><span className="mini-label">NEW CITIZENS</span><h2>Recent arrivals</h2></div></div>{overview.recent_citizens.map(c=><Link className="admin-citizen" href={"/u/"+encodeURIComponent(c.username)} key={c.id}><span>{c.display_name.slice(0,1).toUpperCase()}</span><div><strong>{c.display_name}</strong><small>@{c.username} · {c.area_class}</small></div><b>↗</b></Link>)}</section><section className="admin-side-note"><span className="mini-label">OWNER NOTE</span><p>Keep the street alive. Protect the people. Never confuse noise with activity.</p></section></aside></section>
 <footer className="site-footer"><span>FSOCIETY / AREA OWNER CONSOLE</span><span>Private route. Verified access only.</span><Link href="/">Return to AREA ↗</Link></footer></main>;
}
