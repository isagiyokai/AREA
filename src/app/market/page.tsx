import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import AreaMarket from "@/components/area-market";
export const dynamic="force-dynamic";
export default async function MarketPage(){
 const supabase=await createClient();const {data:{user}}=supabase?await supabase.auth.getUser():{data:{user:null}};
 return <main className="shell market-shell"><header className="top"><Link href="/" className="brand">AREA<span>.</span></Link><div className="account-top-links"><Link href="/">The street ↗</Link><Link href="/wallet">AC wallet ↗</Link><Link href="/account">My account</Link></div></header>
 <section className="market-masthead"><span className="eyebrow">AREA / THE MARKET</span><h1>Put your own<br/><em>stamp on it.</em></h1><p>Profile details, street marks and little things that make your corner yours.</p></section>
 <div className="section-rule"><span>THE SHELVES</span><span>OWN IT · EQUIP IT · KEEP IT</span></div>
 <AreaMarket userId={user?.id??null}/>
 <footer className="site-footer"><span>AREA / MARKET</span><span>AC-only catalogue</span><Link href="/">Back to the street ↗</Link></footer></main>;
}