# Educational Learn topics. Plain Ruby data (no DB) — each capability lesson on
# the Learn index links to one of these detail pages. Copy is drafted sample
# content; edit freely. `related_category` maps to a Rubric category key so the
# page can link to the matching leaderboard.
class LearnTopic
  TOPICS = {
    "writing" => {
      icon: "pencil",
      title: "Writing & editing with AI",
      summary: "How to get genuinely good writing out of AI — and where it still needs you.",
      related_category: "writing",
      sections: [
        { heading: "What it's actually good at",
          body: "Modern models are excellent at the blank-page problem. Give one a rough brief and it returns a structured first draft in seconds — emails, posts, outlines, summaries. They're also strong editors: paste clumsy text and ask for it tighter, warmer, or more formal, and the result is usually a real improvement." },
        { heading: "Where it falls short",
          body: "AI writing drifts toward the generic. Without direction it produces competent, slightly bland prose that reads like everyone else's. It can't reliably imitate your voice unless you show it examples, and it will happily invent specifics — names, stats, quotes — so anything factual needs checking." },
        { heading: "How to get more out of it",
          body: "Give it a role (\"you're a careful technical editor\"), paste an example of the tone you want, and ask for two or three options rather than one. Treat the first output as a draft to react to, not a final answer. The back-and-forth is where the quality comes from." }
      ]
    },
    "research" => {
      icon: "search",
      title: "Research & fact-checking with AI",
      summary: "Using AI to get oriented fast without getting burned by confident mistakes.",
      related_category: "research",
      sections: [
        { heading: "A faster way in",
          body: "For getting up to speed on an unfamiliar topic, AI is a powerful starting point — it can compare options, lay out trade-offs, and point you toward the right vocabulary and sources far quicker than a cold search." },
        { heading: "The trust problem",
          body: "The catch is that AI can be confidently wrong. It may cite a study that doesn't exist or state a figure that's subtly off. The tools that show their sources are far safer, but the habit that matters most is yours: verify anything you'd act on against a primary source." },
        { heading: "Prompts that reduce errors",
          body: "Ask it to cite sources and flag anything it's unsure about. Ask \"what would change your answer?\" to surface assumptions. For numbers, ask where each one came from. These small moves dramatically cut the rate of quiet mistakes." }
      ]
    },
    "coding" => {
      icon: "code",
      title: "Coding with AI",
      summary: "From autocomplete to whole-file edits — what today's coding models can really do.",
      related_category: "coding",
      sections: [
        { heading: "Beyond autocomplete",
          body: "The strongest models write working functions, explain unfamiliar code, find bugs, and refactor across a file. The best can take a described task, investigate the code, and make multi-step changes while preserving behaviour — closer to a junior pair than a snippet generator." },
        { heading: "Where to be careful",
          body: "Accuracy drops on large unfamiliar codebases, edge cases, and anything security-sensitive. Generated code can look right and be subtly wrong, so review remains non-negotiable. Treat it as a fast, tireless collaborator whose work you always check." },
        { heading: "Getting better results",
          body: "Give it the surrounding context, state the constraints, and ask it to explain its approach before it writes. For bugs, paste the error and the relevant code rather than describing them. Iterate in small steps instead of asking for everything at once." }
      ]
    },
    "meetings" => {
      icon: "microphone",
      title: "Meetings & transcription with AI",
      summary: "Turning conversations into accurate notes, decisions, and follow-ups.",
      related_category: "meetings",
      sections: [
        { heading: "What it captures",
          body: "Good tools transcribe audio with speaker labels, then distil it into summaries, decisions, action items, and even send-ready follow-up emails. For meetings you'd otherwise leave without notes, the value is enormous." },
        { heading: "What trips it up",
          body: "Accuracy depends heavily on audio quality, accents, and jargon. Noisy rooms and heavy crosstalk produce errors, and action items can be misattributed — so a quick human pass before you act on them is wise." },
        { heading: "Using it well",
          body: "Record clean audio where you can, give the tool a glossary of names and terms if it supports one, and review the action items for ownership. The summary is a draft of the truth, not the truth itself." }
      ]
    },
    "translation" => {
      icon: "language",
      title: "Translation with AI",
      summary: "Fluent everyday translation — and when to bring in a human.",
      related_category: "translation",
      sections: [
        { heading: "Strong for everyday use",
          body: "For emails, messages, and general content, AI translation is now fluent and natural, preserving tone far better than older tools. For most day-to-day communication it's more than good enough." },
        { heading: "Where nuance matters",
          body: "Legal, medical, and contractual text — or anything where a shade of meaning carries weight — still needs a human translator. AI can miss idiom, register, and culturally specific nuance in ways that matter at the margins." },
        { heading: "Tips",
          body: "Give context about audience and formality, and ask it to flag anything ambiguous. For important text, translate back to the original language as a sanity check." }
      ]
    },
    "summarising" => {
      icon: "file-text",
      title: "Summarising with AI",
      summary: "Shrinking long documents and threads down to what matters.",
      related_category: "writing",
      sections: [
        { heading: "Its sweet spot",
          body: "When you provide the source — a document, transcript, or long thread — AI is excellent at condensing it into a sentence, a few bullets, or key takeaways. It's one of the most immediately useful things these tools do." },
        { heading: "The limit",
          body: "It can only summarise what it can actually see. Ask it to summarise something from memory and it may fill gaps with plausible invention. Very long inputs can also exceed its context window, quietly dropping the earliest material." },
        { heading: "Getting clean summaries",
          body: "Specify the format and length you want, and tell it who the summary is for. Ask for the single most important point first, then supporting detail — it forces a sharper result." }
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
