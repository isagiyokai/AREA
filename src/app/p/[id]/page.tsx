import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import Feed from "@/components/feed";

export const dynamic="force-dynamic";

export default async function PostPage({params}:{params:Promise<{id:string}>}){
 const {id}=await params;
 const supabase=await createClient();
 if(!supabase)notFound();
 const [{data:post},{data:{user}}]=await Promise.all([
  supabase.from("posts").select("id,content,created_at,author_id,quoted_post_id,profiles!posts_author_id_fkey(username,display_name,area_class)").eq("id",id).maybeSingle(),
  supabase.auth.getUser()
 ]);
 if(!post)notFound();
 let quotedPost=null;
 if(post.quoted_post_id){const {data}=await supabase.from("posts").select("id,content,created_at,author_id,profiles!posts_author_id_fkey(username,display_name,area_class)").eq("id",post.quoted_post_id).maybeSingle();quotedPost=data;}
 const feedPost={...post,quoted_post:quotedPost};
 return <main className="shell post-page-shell">
  <header className="top"><Link href="/" className="brand">AREA<span>.</span></Link><nav className="nav"><Link href="/">The street</Link><Link href="/gbas-gbos">Gbas Gbos</Link><Link href="/explore">Explore</Link></nav><div className="top-actions"><Link className="account-link" href={user?"/account":"/login"}>{user?"My account":"Sign in"}</Link></div></header>
  <section className="post-page-intro"><span className="eyebrow">THE STREET / PUBLIC CONVERSATION</span><h1>One post. Plenty gist.</h1><p>Pick up where the conversation started.</p></section>
  <div className="post-page-feed"><Feed initialPosts={[feedPost as Parameters<typeof Feed>[0]["initialPosts"][number]]} initialFollowingPosts={[]} signedIn={!!user} currentUserId={user?.id??null}/></div>
  <footer className="site-footer"><span>AREA © 2026</span><span>Everybody get mouth. Everybody get matter.</span><Link href="/">Back to the street ↗</Link></footer>
 </main>;
}
