# Blogs Guide for This Portfolio

This guide shows how to add blog posts in a static, no-auth workflow using Markdown content plus structured metadata.

It is designed to be additive and safe, so nothing in your existing portfolio (projects, certifications, resume preview) needs to be changed or removed.

## Goals

- Keep blog publishing simple: edit files, commit, deploy.
- Keep data structured: frontmatter metadata drives UI cards and SEO.
- Keep rendering high quality: clean typography, fast loading, responsive layout.
- Keep architecture static-first: no database and no runtime auth required.

## Recommended Content Architecture

Use this folder structure:

```text
src/
  content/
    blogs/
      2026-05-06-agentic-systems.md
      2026-05-10-next16-performance.md
  lib/
    blogs.ts
  app/
    blogs/
      page.tsx
      [slug]/
        page.tsx
```

## Blog File Format (Markdown + Frontmatter)

Each blog post is one `.md` file.

```md
---
slug: agentic-systems-in-production
title: Agentic Systems in Production
description: Practical architecture patterns for multi-agent workflows.
author: Ajay
publishedAt: 2026-05-06
updatedAt: 2026-05-06
tags:
  - agents
  - architecture
  - llm
category: Engineering
coverImage: /blogs/agentic-systems/cover.jpg
readingTimeMinutes: 8
featured: true
draft: false
---

## Why this matters

Your markdown content starts here.

- Keep paragraphs short.
- Use clear section headings.
- Add code blocks when useful.

```ts
export function example() {
  return "clean and production-ready";
}
```
```

## Frontmatter Rules

Required fields:

- `slug`
- `title`
- `description`
- `author`
- `publishedAt`
- `tags`
- `category`
- `draft`

Strongly recommended fields:

- `updatedAt`
- `coverImage`
- `readingTimeMinutes`
- `featured`

Conventions:

- `slug` must be lowercase and hyphenated.
- `publishedAt` format: `YYYY-MM-DD`.
- Keep `description` between 120 and 160 chars for previews.
- `draft: true` means hidden from blog listing.

## Data Contract in App Layer

Create a typed data contract in `src/lib/blogs.ts`.

```ts
export interface BlogPostMeta {
  slug: string;
  title: string;
  description: string;
  author: string;
  publishedAt: string;
  updatedAt?: string;
  tags: string[];
  category: string;
  coverImage?: string;
  readingTimeMinutes?: number;
  featured?: boolean;
  draft: boolean;
}

export interface BlogPost extends BlogPostMeta {
  content: string;
}
```

Then parse all markdown files, return:

- `getAllPosts()` (sorted by date desc)
- `getFeaturedPosts()`
- `getPostBySlug(slug)`
- `getBlogSlugs()` for static params

## Static Rendering Pattern

- `/blogs` page: render cards from metadata only.
- `/blogs/[slug]` page: render one parsed markdown post.
- Use `generateStaticParams` for all non-draft slugs.
- Use metadata for each post page:
  - title
  - description
  - OG image
  - canonical URL

## UI Patterns for a Creative, Clean Blog Experience

### Blog Listing (`/blogs`)

- Hero section with short manifesto line.
- Featured post panel at top.
- Card grid for recent posts.
- Tag chips and category labels.
- Subtle motion on card hover and on first load.

### Blog Reader (`/blogs/[slug]`)

- Strong reading width: `max-w-3xl` or `max-w-4xl`.
- Sticky top utility row:
  - back to blogs
  - reading time
  - share/copy link
- Cover image above title when available.
- Rich typography scale for headings, paragraphs, lists, and code blocks.
- Footer section with related posts.

### Design direction (high quality)

- Keep visual system consistent with your current futuristic theme.
- Use high contrast body text.
- Keep background textures subtle and non-distracting.
- Use motion purposefully, not excessively.

## Markdown Authoring Best Practices

- One core idea per post.
- Use clear section headers (`##`, `###`).
- Prefer examples over abstract statements.
- Keep paragraphs short (2 to 5 lines).
- Add a short summary section at the end.

Recommended structure:

1. Hook / problem
2. Context
3. Solution approach
4. Implementation details
5. Tradeoffs
6. Final takeaway

## Performance and SEO Checklist

For each post:

- Title is unique and clear.
- Description is concise and useful.
- Cover image is optimized and web-friendly.
- `draft` is false only when ready.
- Internal links to related posts exist.
- Heading hierarchy is valid.

## Suggested Publishing Workflow

1. Create a new markdown file in `src/content/blogs/`.
2. Fill frontmatter first.
3. Write content sections.
4. Set `draft: true` while editing.
5. Preview locally.
6. Fix formatting and metadata.
7. Set `draft: false`.
8. Commit and deploy.

## Optional Quality Automation

Add a lightweight validation script later to check:

- slug uniqueness
- required frontmatter fields
- date validity
- minimum description quality

This catches content issues before deploy.

## Non-Breaking Integration Strategy

To avoid impacting existing features:

- Add blog routes and blog lib as new files only.
- Do not modify project and certification data flows.
- Add navbar link to `/blogs` only after blog pages are verified.
- Keep blog CSS scoped to blog pages/components.

## Example Quick Start Post Template

Copy this into a new file:

```md
---
slug: your-post-slug
title: Your Post Title
description: One-line description of what readers will learn.
author: Ajay
publishedAt: 2026-05-07
updatedAt: 2026-05-07
tags:
  - tag1
  - tag2
category: Engineering
coverImage: /blogs/your-post/cover.jpg
readingTimeMinutes: 6
featured: false
draft: true
---

## Intro

Write your opening context.

## Main Idea

Write the core content.

## Implementation

Add practical details and examples.

## Conclusion

Summarize the outcome and next steps.
```

## Final Note

This workflow is how high-quality static portfolios and developer blogs are commonly managed: structured metadata, markdown content, static rendering, and strict editorial conventions.

If you want, next step is I can scaffold the complete `/blogs` and `/blogs/[slug]` implementation with this exact contract and keep it visually aligned with your current portfolio design.
