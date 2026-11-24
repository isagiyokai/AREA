import Link from "next/link";
import { createClient } from "@/lib/supabase/server";

export const dynamic="force-dynamic";

type Citizen={id:string;username:string;display_name:string;area_class:string;bio:string|null};
type SearchPost={id:string;content:string;created_at:string;author_id:string;profiles:{username:string;display_name:string;area_class:string}|{username:string;display_name:string;area_class:string}[]|null};
const profileOf=(v:SearchPost["profiles"])=>Array.isArray(v)?v[0]??null:v;

export default async function ExplorePage({searchParams}:{searchParams:Promise<{q?:string}>}){
 const params=await searchParams;
 const query=(params.q??"").trim().slice(0,80);
 const supabase=await createClient();
 let citizens:Citizen[]=[];let posts:SearchPost[]=[];
 if(supabase&&query){
  const pattern="%"+query+"%";
  const [byHandle,byName,postRows]=await Promise.all([
   supabase.from("profiles").select("id,username,display_name,area_class,bio").ilike("username",pattern).limit(12),
   supabase.from("profiles").select("id,username,display_name,area_class,bio").ilike("display_name",pattern).limit(12),
   supabase.from("posts").select("id,content,created_at,author_id,profiles!posts_author_id_fkey(username,display_name,area_class)").ilike("content",pattern).order("created_at",{ascending:false}).limit(30)
  ]);
  const map=new Map<string,Citizen>();for(const citizen of [...(byHandle.data??[]),...(byName.data??[])])map.set(citizen.id,citizen as Citizen);
  citizens=[...map.values()].slice(0,16);posts=(postRows.data??[]) as SearchPost[];
 }
 return <main className="shell explore-shell">
  <header className="top"><Link href="/" className="brand">AREA<span>.</span></Link><nav className="nav"><Link href="/">The street</Link><Link href="/gbas-gbos">Gbas Gbos</Link><Link className="nav-current" href="/explore">Explore</Link></nav><div className="top-actions"><Link className="account-link" href="/account">My account</Link></div></header>
  <section className="explore-intro"><span className="eyebrow">AREA / LOOK AROUND</span><h1>Find your people.<br/><em>Find the gist.</em></h1><p>Search what people are saying and the citizens saying it.</p></section>
  <form className="explore-search" action="/explore" method="get"><label htmlFor="area-search">SEARCH THE STREET</label><div><input id="area-search" name="q" type="search" maxLength={80} defaultValue={query} placeholder="Try a name, a handle or a topic…"/><button className="btn primary" type="submit">Search ↗</button></div></form>
  {!query?<div className="explore-empty"><strong>Every corner has a conversation.</strong><p>Search for a citizen or a topic to see what is already being said.</p></div>:<div className="explore-results">
   <section className="explore-section"><div className="explore-section-head"><div><span className="mini-label">CITIZENS</span><h2>People matching “{query}”</h2></div><span>{citizens.length} found</span></div>{!citizens.length?<p className="notice">No citizens matched that search.</p>:<div className="explore-citizens">{citizens.map(c=><Link href={"/u/"+encodeURIComponent(c.username)} className="explore-citizen" key={c.id}><span className="explore-avatar">{c.display_name.slice(0,1).toUpperCase()}</span><span><strong>{c.display_name}</strong><small>@{c.username} · {c.area_class.toUpperCase()}</small>{c.bio&&<em>{c.bio}</em>}</span><b>↗</b></Link>)}</div>}</section>
   <section className="explore-section"><div className="explore-section-head"><div><span className="mini-label">PUBLIC POSTS</span><h2>The gist matching “{query}”</h2></div><span>{posts.length} found</span></div>{!posts.length?<p className="notice">No posts matched that search. Try another word or phrase.</p>:<div className="explore-posts">{posts.map(post=>{const author=profileOf(post.profiles);return <article className="explore-post" key={post.id}><div className="explore-post-meta"><Link href={author?.username?"/u/"+encodeURIComponent(author.username):"/explore"}>{author?.display_name||"AREA Citizen"}</Link><span>@{author?.username||"citizen"} · {new Date(post.created_at).toLocaleDateString("en-NG",{day:"numeric",month:"short"})}</span></div><p>{post.content}</p><Link className="text-action" href={"/p/"+post.id}>Open conversation ↗</Link></article>;})}</div>}</section>
  </div>}
  <footer className="site-footer"><span>AREA © 2026</span><span>A Nigerian digital society.</span><Link href="/">Back to the street ↗</Link></footer>
 </main>;
}
