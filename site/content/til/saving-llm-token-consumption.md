---
title: Saving LLM token consumption
date: 2026-04-08 22:51
slug: saving-llm-token-consumption
status: published
pinned: true
---

I recently discovered a way to save LLM token consumption, and its working really well. Previously i found a tweet post by [@nayakayp](https://x.com/nayakayp/status/2041845217171796458) that showed how to use rtk to save token consumption. I was curious to see if it would work with other LLMs, so i tried it with cursor.

rtk-ai use hooks, it invoke when the user type in a prompt via preToolUse hooks. we should know that each we call tools, each turn, the model output is added to the context window.

therefore, hooks pretty good to reduce bloating context window size. For example, when you wanted to force a model to use certain command or rules like "use pnpm instead of npm" we usually write it into AGENTS.md or CLAUDE.md or cursor rules but this is not always effective because the model may not follow the rules or it may not be aware of the rules but with hooks, we can easily achieve this.

## Screenshots

<div class="grid grid-cols-2 gap-4">
  <div class="flex flex-col items-center justify-center gap-4">
    <img src="/assets/images/saving-llm-token-consumption/before.png" alt="before" class="w-32 h-auto object-cover rounded-md" />
    <span class="text-sm text-gray-500">before</span>
  </div>
  <div class="flex flex-col items-center justify-center gap-4">
    <img src="/assets/images/saving-llm-token-consumption/after.png" alt="after" class="w-32 h-auto object-cover rounded-md" />
    <span class="text-sm text-gray-500">after</span>
  </div>
</div>

other way to reduce token consumption is to use smaller models when writing code and use larger models for planning, researching and thinking. like what i do, using Opus 4.6 for planning and brainstorming, and using composer 2 / auto to execute the plan. 

Cursor use composer 2 fast as default to execute subagents, which is a great way to reduce token consumption, CMIIW.


for more information, you can check out the following links:
- [rtk-ai](https://github.com/rtk-ai/rtk)


~ That's it for now, happy ~vibe~ coding! ~