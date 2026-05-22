---
title: Should we rely on LLMs?
date: "2026-05-07T06:30:00+07:00"
slug: should-we-rely-on-llm
section: articles
banner: "/assets/banners/should-we-rely-on-llm.png"
status: published
tags: ["llm", "development"]
---

# DRAFT

TLDR, should we rely on LLMs? If you mean fully rely, then I say no. This article explains how the current AI usage situation can affect our brain, decision-making, tech debt, and cost compared to manual development itself (writing code by hand). Also, how you should manage context to make the model more deterministic.

My friend said he feels left behind with this new shiny AI thing moving so fast, even though he already uses an AI agent in Cursor to help find bugs. I said to him, "well, not all AI news really makes huge improvement for you, since you work with a large codebase, even private. And for scoped work, you need to be fully responsible for the code you produce."

## Forcing LLM to be Deterministic
First rule when using an LLM is to force it to be more deterministic and accurate. Previously, what do we do? Add more context and context, more code by mentioning the whole `@src/` folder, and filling references with the RAG method to reduce ambiguity. Is this going to reduce hallucination? The answer is maybe yes in several conversation turns. Remember that in each turn we add a new prompt + system prompt + previous context. The more context you fill, the less accurate it becomes and the more it hallucinates. More tokens mean more $$$ cost :)

Yes, people are also gonna say it is a skill issue if you cannot create a proper prompt, workflow, and harness, or maybe that you should know how to be token-efficient. But did you ever learn how they work? Did you read the code that LLMs generate? Or do you simply go "plan A based on this, go write" -> "fix this and that, make no mistake". This behavior is reasonable when playing around to make an MVP product or something you use yourself.

## More SPEC files in a bunch of .md
What solution do they add? More prompt blueprints by creating `AGENTS.md` and `CLAUDE.md`. These two files are enough to enforce important rules, but in some cases we become insecure, so adding more `.md` files like `[IMPORTANT_SPEC_STUFF].md`, `[ROLEPLAY_GUIDE].md`, and `[PLAN].md` might feel great but ends up making the model confused.

## Compaction
Another solution is to use compaction. Compaction is the process of reducing the size of the context window by removing redundant or unnecessary information. This is important because the more context you have, the more tokens you need to send to the model. The model has a limit on the number of tokens it can process, so you need to be careful not to exceed this limit. The downside of compaction is that you lose some information, so you need to be careful not to lose too much.
