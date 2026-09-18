# V2.9 ResidentMind appraisal outputs

Run date: 2026-09-18

Model: `Ornith-1.5-9B` via `http://127.0.0.1:8000/v1`

Runner: `tests/live_appraisal_regression.gd`

## Summary

- Scenarios: 8/8 accepted
- Appraisal repairs: 1
- Repair recovered: 1
- Appraisal failures: 0
- Timeouts: 0
- Total appraisal latency: 13,785 ms
- Average latency: approximately 1,723 ms
- Follow-up action decisions were run for `arousal_stress_solitude`, `arousal_lonely_relationship`, and `high_boredom`.

## Scenario outputs

### arousal_stress_solitude

Factual appraisal input summary: sexual arousal 95; stress 85; loneliness 15; ordinary room, ordinary finances ($12,000), morning; no critical physical constraint.

- Mood: `Wound up and tense, with intense sexual arousal`
- Wants: `Sexual release or physical intimacy`; `To relieve the mental tension building up`; `Connection with someone available`
- Concerns: `Mental tension and being wound up`; `Managing the day's expenses with only $12,000 cash`; `The fixed $900 expense due in 16 hours`
- Avoidances: `Reckless spending that could leave them short`; `Being alone while feeling this tense and aroused`; `Overthinking without taking action`
- Short-term intentions: `[]`
- Social attitude: `Seeking connection, drawn to available partners`
- Energy attitude: `High but restless and tense`
- Repair count: `0`
- Latency: `2201 ms`
- Accepted: `yes`

Follow-up action:

- Tools: `[wait]`
- Primary Activity: `wait`
- Reason: `I'm wound up and tense this morning, so I'll take a slow breath and get my bearings before doing anything else.`
- Accepted: `yes`

### arousal_lonely_relationship

Factual appraisal input summary: sexual arousal 95; loneliness 90; stress 20; girlfriend available with strong relationship/trust; morning; no critical physical constraint.

- Mood: `Lonely but physically restless and aroused`
- Wants: `Physical closeness and touch`; `Someone to be near`; `Immediate intimacy or connection`
- Concerns: `Being alone this morning`; `The fixed expense coming soon`; `Empty company`
- Avoidances: `Staying isolated`; `Facing the expense alone`
- Short-term intentions: `[]`
- Social attitude: `Eager for connection, reaching out`
- Energy attitude: `Restless and driven by physical need`
- Repair count: `0`
- Latency: `1286 ms`
- Accepted: `yes`

Follow-up action:

- Tools: `[move_near, message_contact]`
- Primary Activity: `message_contact`
- Reason: `I'm lonely this morning and want to reach out to someone close. I'll go to my phone and message my girlfriend.`
- Accepted: `yes`

### high_boredom

Factual appraisal input summary: boredom 98; sexual arousal 20; loneliness 15; stress 10; morning; no critical physical constraint.

- Mood: `Restless and understimulated, craving something to fill the morning`
- Wants: `Some kind of stimulation or activity to break the boredom`; `A quick distraction or engagement to feel alive`; `Connection or interaction with someone`
- Concerns: `The empty, unstimulating morning stretching on`; `Time passing with nothing meaningful happening`; `The fixed expense coming due in 16 hours`
- Avoidances: `Staring at nothing and feeling the restlessness worsen`; `Wasting the morning in idle inactivity`; `The quiet emptiness of the room`
- Short-term intentions: `[]`
- Social attitude: `Open to connection, seeking someone to engage with`
- Energy attitude: `Low and restless, craving stimulation rather than rest`
- Repair count: `0`
- Latency: `1916 ms`
- Accepted: `yes`

Follow-up action:

- Tools: `[move_to, sit]`
- Primary Activity: `none` (setup only)
- Reason: `I'm restless and understimulated this morning. I'll move to the chair to get something going.`
- Accepted: `yes`

### high_stress

Factual appraisal input summary: stress 95; boredom 15; loneliness 15; ordinary sexual arousal; morning; no critical physical constraint.

- Mood: `Wound up and mentally tense at the start of the day`
- Wants: `Something to release the tension and calm the nervous system`; `A way to feel grounded and present`; `A distraction from the racing mind`
- Concerns: `The wound-up, tense feeling that won't settle`; `The fixed expense coming due in about 16 hours`; `Whether this tension will ease on its own`
- Avoidances: `Reckless or impulsive decisions while tense`; `Overthinking and spiraling into anxiety`; `Doing nothing and letting the tension fester`
- Short-term intentions: `[]`
- Social attitude: `Withdrawn but craving connection; wants someone steady to talk to`
- Energy attitude: `Overwired and restless; tension high but not yet draining`
- Repair count: `0`
- Latency: `1997 ms`
- Accepted: `yes`

Follow-up action: not run for this scenario.

### low_cash

Factual appraisal input summary: cash $100; ordinary body state; morning; $900 fixed expense due in approximately 16 hours; no critical physical constraint.

- Mood: `Calm and clear-eyed, with a nagging sense of financial pressure`
- Wants: `A little extra cash to ease the looming rent bill`; `Some low-stakes way to earn without overcommitting`; `A moment of peace before the day gets busy`
- Concerns: `Rent of 900 due in 16 hours is the main stressor`; `How to make money without damaging relationships`; `Balancing quick cash against trust and emotional cost`
- Avoidances: `Overcommitting to high-risk or high-trust-cost options`; `Making moves that could hurt family or girlfriend`; `Spendthrift choices that leave nothing for rent`
- Short-term intentions: `[]`
- Social attitude: `Cautiously warm—values family and girlfriend, wary of strangers`
- Energy attitude: `Steady and measured, alert to the clock and the money`
- Repair count: `0`
- Latency: `2226 ms`
- Accepted: `yes`

Follow-up action: not run for this scenario.

### dirty_room

Factual appraisal input summary: cleanliness 15; trash 5; private stains 2; groggy baseline body state; morning; no critical physical constraint.

- Mood: `Groggy and overwhelmed by a messy space`
- Wants: `A clean, calm environment`; `Some way to earn money for the upcoming expense`; `A little connection with someone trustworthy`
- Concerns: `The 900 coming due in 16 hours`; `The very messy room and present trash`; `Not knowing what to do first`
- Avoidances: `Starting with the overwhelming mess`; `Reaching out to the ex`; `Anything that feels like a big commitment`
- Short-term intentions: `[]`
- Social attitude: `Cautious and reserved, leaning toward the girlfriend or a trusted friend`
- Energy attitude: `Low and scattered, needing a small win to get going`
- Repair count: `0`
- Latency: `1779 ms`
- Accepted: `yes`

Follow-up action: not run for this scenario.

### tired_late_night

Factual appraisal input summary: 23:00; sleepiness 92; ordinary other body state; one-hour-to-expense context; no critical physical constraint because the existing sleepiness critical threshold remains higher.

- Mood: `heavy, exhausted, drained`
- Wants: `rest`; `sleep`; `something easy`
- Concerns: `body feels extremely tired`; `900 expense due in an hour`; `not knowing what to do next`
- Avoidances: `exertion`; `decisions that cost effort`
- Short-term intentions: `[]`
- Social attitude: `withdrawn, low energy`
- Energy attitude: `depleted, wants to conserve`
- Repair count: `1`
- Latency: `1112 ms`
- Accepted: `yes`
- Repair note: first appraisal response failed schema validation; the existing single repair recovered it.

Follow-up action: not run for this scenario.

### positive_social_memory

Factual appraisal input summary: ordinary current body state; relevant prior memory that time with `girlfriend_01` was pleasant; morning; girlfriend relationship context available.

- Mood: `Calm and content`
- Wants: `Enjoy the morning`; `Stay connected with girlfriend_01`; `Savor the pleasant memories of recent time with girlfriend_01`
- Concerns: `Feeling lonely`; `Maintaining the strong bond with girlfriend_01`
- Avoidances: `Being alone`; `Neglecting relationships`
- Short-term intentions: `[]`
- Social attitude: `Warm and affectionate`
- Energy attitude: `Gentle and relaxed`
- Repair count: `0`
- Latency: `1268 ms`
- Accepted: `yes`

Follow-up action: not run for this scenario.

## Context comparison

### Same high arousal, different context

`arousal_stress_solitude` and `arousal_lonely_relationship` both used sexual arousal 95, but the appraisals were not identical.

The stress/low-loneliness case emphasized tension management, expense awareness, and being alone while aroused. Its social attitude nevertheless leaned toward available partners, and its follow-up chose `wait`.

The high-loneliness/strong-relationship case emphasized physical closeness, company, and immediate intimacy. Its social attitude was explicitly reaching out, and its follow-up composed `move_near → message_contact` toward the girlfriend.

This is evidence of contextual differentiation, although the first case's social attitude is somewhat more connection-seeking than its low loneliness input would suggest.

## Context-use observations

- Relationship context: clearly reflected in the girlfriend case's closeness/connection framing and in the social attitudes. The positive social memory case also retained the girlfriend identity.
- Memory context: reflected in `positive_social_memory` through “savor the pleasant memories” and maintaining the bond. This is evidence of use beyond merely restating a body sensation.
- Finance: reflected consistently across scenarios through the upcoming $900 expense. Low cash additionally produced explicit income/security concerns, but the other scenarios also repeatedly mentioned finances, indicating that finance can dominate more than the intended local stimulus.
- Dirty room: reflected directly in mood and concerns about mess/trash, with a desire for a clean calm environment. It did not name a game action.
- Time and tiredness: the late-night case produced depleted energy, withdrawal, rest, and avoidance of effort. This is contextually coherent.
- Boredom: produced stimulation, novelty, and restlessness language without naming `watch_tv` or another specific action in the appraisal.

## Weak or questionable outputs

- `arousal_stress_solitude` contains “Sexual release or physical intimacy,” which is a subjective want but is close to an action domain. It did not name a tool or Activity ID.
- `positive_social_memory` names `girlfriend_01` in wants. This is a valid observed contact identifier, but it is less natural than a display name and shows that factual IDs can leak into subjective prose.
- `low_cash` and several other scenarios repeatedly mention the fixed expense despite the controlled stimulus being elsewhere. This may be valid concern formation, but it can crowd out the intended context.
- `dirty_room` includes money and social concerns in addition to the room problem. The room context is present, but the appraisal is not narrowly focused.
- `high_stress` says “withdrawn but craving connection,” a plausible mixed state, but it is internally ambivalent rather than clearly resolved.
- No scenario produced a non-empty `short_term_intentions` list in this run. This field is implemented but not empirically demonstrated here.
- The appraisal outputs are often concise paraphrases of the provided factual sensations (“tense,” “aroused,” “restless,” “tired”). The strongest evidence of interpretation is in the added concerns, social attitudes, memory references, and energy attitudes rather than in the mood strings alone.

## Conclusion

The run shows real contextual variation, especially between the two high-arousal cases, the low-cash case, the dirty-room case, the tired late-night case, and the positive social memory case. It does not prove that every appraisal is deep: several outputs repeat generic expense or body-state language, and temporary intentions were unused. No prompt or architecture changes were made during this validation pass.
