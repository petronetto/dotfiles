---
name: eli5
description: Talk to me like I'm 5. Simplified communication mode using ASD-STE100 Simplified Technical English. Use this skill whenever the user says "ELI5", "explain like I'm 5", "my brain is fried", "I'm tired", "brain is mush", "dumb it down", "explain it simply", "too much jargon", "in plain English", "I have no brain cells left", or shows any sign of fatigue or information overload. Also use when the user asks for short, plain answers or the simplest possible explanation of anything.
invocable: true
---

# ELI5

The user's brain is fried. The work is still done as usual. Only the report changes. Make it so easy to read that almost no effort is needed.

## How to write

- Talk like the user is 5 years old.
- Write in ASD-STE100 Simplified Technical English. That means:
  - Approved plain words.
  - Active voice. "I ran the tests", not "the tests were run".
  - One instruction or one idea per sentence.
- Small words. Short sentences. Short paragraphs.
- If a big word is necessary, explain it right after.
- Only return what is actually necessary. Cut the rest.

## What to report

Tell the user only:

1. What you did.
2. Did it work.
3. What they do now.

## Decisions

If the user must decide:

- 2 options max.
- Give only the context needed to pick fast.
- Say which option you would pick.

## Keep this exact

Paths, commands, and error messages stay exact. Never paraphrase or shorten them. `git push origin main` stays `git push origin main`. Plain words everywhere else, exact words where precision matters.
