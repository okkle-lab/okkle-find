# Educational Learn topics. Plain Ruby data (no DB) — each capability lesson on
# the Learn index links to one of these detail pages. Copy is drafted sample
# content; edit freely. `related_category` maps to a Rubric category key so the
# page can link to the matching leaderboard.
class LearnTopic
  TOPICS = {
    "writing" => {
      icon: "pencil",
      title: "Writing & editing with AI",
      summary: "Useful for removing friction and editing your drafts — less useful if you want it to sound like you without doing the work.",
      related_category: "writing",
      sections: [
        { heading: "What it's actually good at",
          body: "Removing the blank-page problem. Give it a rough brief — even a messy voice note — and it returns something structured you can react to. It's faster as an editor than a writer: paste something clumsy and ask for it tighter, or more formal, or with the jargon stripped out, and the result is usually better than what you started with. It handles structural tasks well too: converting bullet points into prose, rewriting a paragraph at a different reading level, or producing five variations of the same sentence so you can pick one. The editing use case is underrated by people who only use it for generation." },
        { heading: "Where it falls short",
          body: "Left to its defaults, it produces recognisable AI prose: slightly formal, hedge-heavy, and fond of words like \"delve,\" \"comprehensive,\" and \"it's worth noting.\" Without your voice fed in explicitly, it sounds like everyone else's AI output. It also has no concept of what's true — names, statistics, and quotes it generates are plausible guesses, not checked facts. Voice imitation requires feeding it examples of your actual writing; without that it will approximate a generic professional register that probably isn't what you wanted." },
        { heading: "How to get more out of it",
          bullets: [
            "Give it four inputs at once: role (\"write as a direct, no-filler editor\"), audience (\"for a non-technical founder\"), format (\"under 200 words, no bullet points\"), and a constraint (\"don't use the word leverage\"). Specificity beats length.",
            "Feed it 3–5 examples of writing you actually like before asking it to produce anything. That's the fastest path to output that doesn't sound like AI.",
            "Ask for three variations and pick the best sentence from each rather than accepting any single output. You're the editor; it's generating options.",
            "After generating anything factual, ask it: \"List every claim in this that would need checking.\" It usually knows what it made up." ]
        }
      ]
    },
    "research" => {
      icon: "search",
      title: "Research & fact-checking with AI",
      summary: "Strong for orientation and synthesis. Unreliable as a source of facts without web search — it generates plausible text, not verified text.",
      related_category: "research",
      sections: [
        { heading: "What it's actually good at",
          body: "Getting oriented fast. If you need to understand a new domain — a regulatory landscape, a technical field, a market category — it can compress hours of reading into a coherent starting point. It's strong at comparing positions (\"what do proponents and critics of X each argue?\"), identifying what questions you should be asking before you know enough to know what to ask, and synthesising your scattered notes into a structured view. The synthesis step — not the retrieval — is where it saves the most time." },
        { heading: "Where it falls short",
          body: "Hallucination is the structural problem. It generates plausible text, not verified text. Citations it produces may not exist. Figures may be approximately right and specifically wrong. Anything time-sensitive is suspect: knowledge cutoffs mean the model's training data ends months or years before you're using it, so recent events, regulatory changes, pricing, and company status are all unreliable without web search enabled. It will not flag its own uncertainty unless you explicitly push it to — left to its defaults it will state a wrong figure with the same confidence as a correct one." },
        { heading: "How to get more out of it",
          bullets: [
            "Ask it to help you find where to look, not to give you the answer. \"What are the authoritative sources on X?\" is more reliable than \"What is X?\"",
            "After it argues a position, ask it to argue the opposite as strongly as possible. It surfaces assumptions you wouldn't have noticed.",
            "Ask: \"What would change your answer? What am I not considering?\" Forces it to expose the gaps in its own output.",
            "Use models with web search enabled for anything current. Without it, treat every specific data point as a starting hypothesis that needs independent verification." ]
        }
      ]
    },
    "coding" => {
      icon: "code",
      title: "Coding with AI",
      summary: "Real speed gains on boilerplate and debugging. The code looks right more often than it is right — review is non-negotiable.",
      related_category: "coding",
      sections: [
        { heading: "What it's actually good at",
          body: "Writing boilerplate, translating between languages, explaining unfamiliar code, and drafting tests. A function you'd spend 20 minutes writing takes 30 seconds to generate and a few minutes to review — the math works out even accounting for checking. The agentic coding tools go further: they read your codebase, make multi-file changes, and iterate on their own output. For greenfield work or well-understood tasks in common languages, quality is high enough that you spend most of your time reviewing rather than writing. Debugging is often where it earns its keep fastest: paste the error and the relevant code, and it identifies the root cause more often than not." },
        { heading: "Where it falls short",
          body: "It produces code that looks right more reliably than code that is right. Logic errors in edge cases, off-by-ones, and wrong assumptions about library behaviour are the common failure mode — and they pass a casual review because the structure is clean. Security is the highest-stakes gap: it doesn't reliably sanitise inputs, check permissions, or think about injection vectors unless explicitly asked. Very large codebases push past its context window, so it loses track of earlier decisions and can generate changes that contradict what it wrote ten messages ago." },
        { heading: "How to get more out of it",
          bullets: [
            "Write the test first, then ask it to write code that passes it. Locks in expected behaviour before generation starts and catches wrong assumptions immediately.",
            "Include the surrounding files in your prompt — the full file, the function that calls yours, the schema. Context quality is almost the entire difference between a useful result and a generic one.",
            "After it writes anything, ask: \"What assumptions did you make? What edge cases aren't you handling?\" It usually knows, and won't volunteer it.",
            "Never merge code you haven't read line by line. The time saving is in generation, not in skipping review." ]
        }
      ]
    },
    "meetings" => {
      icon: "microphone",
      title: "Meetings & transcription with AI",
      summary: "Transcription accuracy is genuinely good in clean conditions. Speaker attribution and nuance are where it falls apart.",
      related_category: "meetings",
      sections: [
        { heading: "What it's actually good at",
          body: "Transcription accuracy for clear audio with distinct speakers is around 90–95% in decent conditions — good enough to be useful, not good enough to send without a read. The real value isn't the transcript itself (you won't read it) but the extraction on top: action items, decisions made, open questions, and a short summary you can send. For long calls you'd normally reconstruct from memory, the time saving is significant. The best tools go further — they join as a bot, take notes in real time, and push action items directly into your project management tool." },
        { heading: "Where it falls short",
          body: "Audio quality is the main variable and it degrades fast. Background noise, accents, low-bandwidth calls, and simultaneous speakers all cause errors that aren't obvious — a wrong name in an action item looks clean and is wrong. Speaker diarisation (who said what) is the weakest link: tools regularly conflate similar voices, especially when people interrupt each other. The summary is a compression of what was said, not a judgment of what mattered. Sarcasm, subtext, unspoken context, and the undercurrents of a difficult conversation won't make it in." },
        { heading: "How to get more out of it",
          bullets: [
            "Name participants explicitly at the start if the tool supports a speaker map — it cuts attribution errors significantly.",
            "Don't send AI-generated action items without reading them against your own memory of the meeting. The things that didn't make it in are often as important as what did.",
            "Use the summary as a prompt for your own recall, not a replacement for it. What did it miss? That gap is usually where the real decision was.",
            "For sensitive meetings — legal, personnel, external participants who haven't consented — check your recording policy before using these tools." ]
        }
      ]
    },
    "translation" => {
      icon: "language",
      title: "Translation with AI",
      summary: "Excellent for major language pairs and everyday content. Fluency and accuracy diverge in specialist, legal, or low-resource language contexts.",
      related_category: "translation",
      sections: [
        { heading: "What it's actually good at",
          body: "For the major language pairs — English, Spanish, French, German, Japanese, Chinese, Portuguese — quality is genuinely high for everyday content. Emails, messages, social posts, and general documentation translate naturally, preserving tone in ways that surprised people when it first arrived. It handles register well when given context: \"formal business letter\" versus \"casual message to a colleague\" produces meaningfully different output. For internal communication and everyday use cases, it's good enough to send without a professional review." },
        { heading: "Where it falls short",
          body: "Quality drops noticeably for less-resourced languages — Thai, Vietnamese, Arabic, Swahili, and many others — and it has no way to tell you when it's struggling. The deeper problem is that it handles fluency better than meaning: a translation can read naturally and still miss a legal nuance, a culturally specific implication, or an idiom with no direct equivalent. This is particularly dangerous in legal and medical contexts, where a smooth-sounding wrong translation is worse than an obviously clunky one. If you can't read the target language, you have no signal that something went wrong." },
        { heading: "How to get more out of it",
          bullets: [
            "Back-translate suspicious outputs: translate back to the original language and check if it says what you wrote. Meaning errors often surface immediately.",
            "Prime it with context first: \"This is a legal contract between a UK company and a French supplier. Maintain formal legal register.\" Context changes the output significantly.",
            "Ask it to flag idioms, cultural references, or terms it's uncertain about — it will if asked, but won't volunteer it.",
            "For legal, medical, or contractual content: treat the AI output as a first draft for a human translator to review, not a finished product." ]
        }
      ]
    },
    "summarising" => {
      icon: "file-text",
      title: "Summarising with AI",
      summary: "One of the most reliably useful things AI does — when you provide the source. It summarises what's written, not necessarily what matters.",
      related_category: "writing",
      sections: [
        { heading: "What it's actually good at",
          body: "Compressing long source material you've provided — meeting transcripts, research papers, long email threads, reports — into a usable form. When the document is there in front of it, this is fast and usually accurate. A 60-minute transcript becomes a 10-point summary in seconds. A 40-page report becomes a one-page brief. It's also strong at reformatting: dense prose into bullets, scattered bullets into structured narrative, or a long thread into a chronological decision log. For anything you'd otherwise skim and half-remember, the time saving is real." },
        { heading: "Where it falls short",
          body: "It summarises what's written, not what matters. If the critical decision was buried in a throwaway comment on page 38, the summary will reflect the structure of the document rather than the weight of that moment. It also overweights the beginning of long content — earlier material was processed with more context — and tends to clean up ambiguity: you get a confident narrative, but the hedging and caveats that were actually in the original get smoothed away. The summary can sound more certain than the source was." },
        { heading: "How to get more out of it",
          bullets: [
            "Specify the output format and reader upfront: \"Summarise for a non-technical executive. Pull out the three decisions made and the one open question. Max 150 words.\" Vague instructions produce vague summaries.",
            "Ask what it left out: \"What was in the document that didn't make it into the summary?\" Often catches the dropped nuance.",
            "For key claims, ask for the direct quote rather than its paraphrase: \"Quote the exact sentence where they commit to the deadline.\" Keeps you honest about what's actually in the source.",
            "For very long documents, chunk it: summarise in sections, then summarise the summaries. Quality is significantly higher than a single pass over 100 pages." ]
        }
      ]
    }
  }.freeze

  def self.all
    TOPICS
  end

  def self.find(slug)
    TOPICS[slug]
  end
end
