# 01. Market Research & Anime/Manga Creator Pain Points

**Language / 语言**: **English** | [简体中文](../zh-CN/01-market-research.md)

---

## 1. Market Landscape Overview (iPad Creative Ecosystem)

By 2026, the iPad has become one of the most popular mobile workstations for anime illustrators, Japanese-style page manga artists, and full-color Webtoon creators. However, existing drawing apps remain fragmented across **touch ergonomics**, **dedicated manga primitives**, **pricing models**, and **open-source licensing**.

### 1.1 Competitive Matrix

| Application | iPad Pricing Model | Key Strengths (Benchmarks to Learn From) | Core Gaps & Pain Points (Opportunity Space) | License |
| :--- | :--- | :--- | :--- | :--- |
| **Procreate** | One-time (\$12.99) | • **Gold standard for touch UX**: minimalist fullscreen canvas, two-finger undo / three-finger redo, ColorDrop, QuickShape<br>• **Custom Metal engine (Valkyrie)**: ultra-low 120Hz ProMotion latency, deep Apple Pencil Pro Squeeze & Barrel Roll support<br>• Built-in timelapse recording | • **Severely lacks manga tools**: no true vector lineart layers, no vector intersection eraser, no panel frame folders, no non-destructive screentones, no vertical CJK lettering or multi-page management<br>• Strict RAM-bound layer cap at high print resolutions<br>• Locked exclusively to iPad | Proprietary |
| **Clip Studio Paint (CSP)** | iPad **Subscription-Only** (Pro / EX) | • **Manga industry standard**: vector layers + vector intersection eraser, benchmark G-Pen feel and stabilizer<br>• Reference-layer close-gap fill, panel folders, non-destructive screentones, 3D pose figures, LT photo-to-lineart, EX multi-page management<br>• Massive ASSETS marketplace | • **Desktop-ported UI**: dense panels feel cramped on touchscreens with a steep learning curve<br>• Subscription-only on tablets alienates students and indie creators<br>• Flagship manga tools (LT conversion, multi-page) gated behind expensive EX tier | Proprietary |
| **ibisPaint X** | Freemium (Ads + Subscription) | • **Fast everyday anime workflow**: best-in-class close-gap & edge-expand bucket fill (eliminates white halos), QR brush sharing<br>• Built-in frame divider, rulers, screentones, and free timelapse export<br>• Broad iPad / Android / PC reach | • Free tier disrupted by ads; advanced tools (vector layer, filters, cloud) increasingly paywalled<br>• Weaker print-grade CMYK and long-form chapter management | Proprietary |
| **MediBang Paint / Jump Paint** | Freemium (Ads + Subscription) | • Purpose-built for comics: free cloud fonts, screentones, panels, and team cloud workflow<br>• Beginner-friendly entry barrier | • Dated interface; brush responsiveness and high-refresh latency trail Procreate and CSP<br>• Ads interrupt creative flow | Proprietary |
| **Adobe Fresco** | Free | • Exceptional live watercolor/oil physics; native raster + vector brush mixing | • Virtually no anime/manga production primitives (panels, screentones, speech bubbles, cel-shading flatting) | Proprietary |
| **Infinite Painter / HiPaint** | One-time / IAP | • Clean Procreate-inspired touch UX with strong Android tablet presence<br>• Capable perspective guides | • Illustration-focused; lacks vector intersection eraser, panel masking, screentones, and manga AI workflow | Proprietary |
| **Krita** | Free & Open Source | • Leading open-source painting app on Desktop and Android; deep brush engine, CMYK, animation | • **GPLv3 license conflicts with Apple App Store terms — unavailable on iPadOS**<br>• Touch UI remains desktop-oriented | Open Source (**GPLv3**) |

---

## 2. Strategic Ecosystem Gap: The MIT License Advantage

1. **Closing the iPadOS Open-Source Vacuum**: Copyleft licenses such as GPLv3 (Krita) and GPLv2+ (MyPaint GUI) are legally incompatible with Apple App Store distribution terms. Adopting the permissive **MIT License** unlocks compliant App Store / TestFlight distribution while empowering community contributors, indie studios, and third-party brush/plugin ecosystems.
2. **Capturing the Sweet Spot ("Procreate Feel × CSP Manga Core × ibisPaint Speed")**:
   - Instead of building a bloated desktop Photoshop clone, we focus tightly on **anime illustration, page manga, and Webtoon production**.
   - Professional manga primitives (reference-layer expand fill, vector intersection eraser, frame slicing) are redesigned from first principles for touch and Apple Pencil Pro.

---

## 3. Daily Anime & Manga Creator Pain Points

Analyzing real-world page manga, doujinshi, and Webtoon production pipelines reveals six major mechanical bottlenecks:

1. **Tedious Inking & Clean-up**: Rough sketches carry energy, but clean inking strains wrists, and intersecting hair/cloth overshoots require endless zooming and erasing.
2. **Cel-Shading Flatting (Largest Time Sink)**: Standard flood-fill leaks through 1–3px lineart gaps or leaves jagged white halos without pixel expansion; artists also manually separate skin, hair, eyes, and outfits into individual layers.
3. **Perspective & Anatomy Breakdown**: Switching between external 3D pose apps and the canvas breaks flow, and realistic 3D dolls clash with anime proportions.
4. **Background Drawing & Screentone Workload**: Hand-drawing classrooms, streets, and interiors is grueling, while CSP's photo/3D LT conversion is locked behind the costly EX subscription.
5. **Repetitive Cel-Shading Lighting**: Serialized Webtoons run 50–80 panels per episode, making repetitive shadow blocking fatiguing.
6. **Continuity Errors & Multilingual Lettering**: Artists frequently forget hairpins, earrings, or heterochromia across panels; translating vertical CJK comics into horizontal English/Spanish bubbles creates layout overhead.

---

## 4. Product Inspiration Matrix

| Benchmark | What We Learn | How We Elevate It |
| :--- | :--- | :--- |
| **Procreate** | Minimalist canvas, 2/3-finger undo/redo, long-press eyedropper, Apple Pencil Pro tuning | Preserve a distraction-free *Focus Mode* while breaking high-DPI layer caps via tile disk paging |
| **Clip Studio Paint** | Vector lineart, vector intersection eraser, G-Pen dynamics & stabilizer, reference layers, panel folders, non-destructive screentones | Re-architect for touch via Pencil Pro radial menus and a clean dockable *Manga Studio Mode* |
| **ibisPaint X** | Ultra-fast close-gap & expand-edge bucket fill, effortless timelapse export, shareable brush culture | Match flatting speed with zero ads, zero paywalls, and open MIT brush/screentone formats |
| **MediBang Paint** | Accessible manga onboarding and lettering templates | Deliver native CJK vertical + EN/ES horizontal lettering and local-first AI production aids |
