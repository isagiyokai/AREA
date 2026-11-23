import type { Metadata } from "next";
import "./globals.css";
export const metadata: Metadata = { title: "AREA — A Nigerian Digital Society", description: "Your people. Your streets. Your AREA." };
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) { return <html lang="en"><body>{children}</body></html>; }
