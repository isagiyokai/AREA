import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import AcWalletPanel from "@/components/ac-wallet-panel";
export const dynamic="force-dynamic";
export default async function WalletPage(){
 const supabase=await createClient();if(!supabase)redirect("/login");
 const {data:{user}}=await supabase.auth.getUser();if(!user)redirect("/login");
 const {data}=await supabase.rpc("get_my_ac_wallet");
 const paymentsEnabled=Boolean(process.env.PAYSTACK_SECRET_KEY&&process.env.SUPABASE_SERVICE_ROLE_KEY);
 return <main className="shell wallet-shell">
  <header className="top"><Link href="/" className="brand">AREA<span>.</span></Link><div className="account-top-links"><Link href="/account">My account ↗</Link><Link href="/">The street ↗</Link></div></header>
  <section className="wallet-masthead"><span className="eyebrow">AREA / THE INTERNAL ECONOMY</span><h1>Money makes<br/>the <em>street move.</em></h1><p>Your AC, your transfers and every movement recorded. No invisible deductions.</p></section>
  <div className="section-rule"><span>THE WALLET</span><span>EVERY MOVE HAS A RECORD</span></div>
  <AcWalletPanel initialWallet={data as {balance_ac:number;history:never[]}|null} paymentsEnabled={paymentsEnabled}/>
  <footer className="site-footer"><span>AREA / AC ECONOMY</span><span>Internal currency ledger</span><Link href="/">Back to the street ↗</Link></footer>
 </main>;
}
