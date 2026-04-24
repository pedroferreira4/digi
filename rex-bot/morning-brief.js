require('dotenv').config({ path: `${__dirname}/.env` });
const { WebClient } = require('@slack/web-api');
const { spawn } = require('child_process');
const { getTranscriptForMeeting, summariseTranscript, extractMeetingId } = require('./zoom');
const fs = require('fs');
const path = require('path');

const VAULT = '/Users/pedro.ferreira4/Documents/ferreira-vault-blip';

const slack = new WebClient(process.env.SLACK_BOT_TOKEN);

// Skip weekends
const day = new Date().getDay();
if (day === 0 || day === 6) process.exit(0);

const today = new Date().toISOString().split('T')[0];

const prompt = `You are Rex, Pedro's meeting agent. Today is ${today}.

Do the following in order:

1. Search Pedro's Outlook calendar for today's events using the M365 connector.
   - Skip any event with "Kraken" in the title
   - Skip declined events
   - Skip all-day events that aren't real meetings

2. For each remaining meeting, create a note at:
   /Users/pedro.ferreira4/Documents/ferreira-vault-blip/Meeting briefs/${today} <meeting title>.md

   Use this format:
   ---
   date: ${today}
   time: HH:MM
   attendees: [list]
   status: upcoming
   ---

   # <Meeting title>

   **Date:** ${today} HH:MM
   **Organiser:** name
   **Attendees:** list

   ## Agenda
   <from invite body, or "No agenda set">

   ## Notes

   ## Action items

3. Output a plain-text summary of today's meetings in time order, like:
   Morning brief — ${today}

   09:00  PromoHub sync (30 min) — You, Alice, Bob
   14:00  1on1 with manager (1 hour) — You, Manager

   Notes written to Obsidian.

   If there are no meetings, say so.`;

function runClaude(input) {
  return new Promise((resolve, reject) => {
    const proc = spawn('claude', ['--print'], {
      stdio: ['pipe', 'pipe', 'pipe'],
      env: process.env,
    });

    let out = '';
    let err = '';

    proc.stdout.on('data', d => { out += d.toString(); });
    proc.stderr.on('data', d => { err += d.toString(); });
    proc.on('close', code => {
      if (code === 0) resolve(out.trim());
      else reject(new Error(`claude exited ${code}: ${err}`));
    });

    proc.stdin.write(input);
    proc.stdin.end();
  });
}

async function run() {
  try {
    console.log(`[rex] Running morning brief for ${today}...`);
    const summary = await runClaude(prompt);

    await slack.chat.postMessage({
      channel: process.env.SLACK_USER_ID,
      text: summary,
    });

    console.log('[rex] Brief sent to Slack.');

    // After the morning brief, try to fetch Zoom transcripts for any
    // meetings that ended in the last 24 hours and have a Zoom link
    await fetchPendingTranscripts();

  } catch (err) {
    console.error('[rex] Morning brief failed:', err.message);

    // Still try to notify even on failure
    await slack.chat.postMessage({
      channel: process.env.SLACK_USER_ID,
      text: `> [!rex]\n> **Rex here.** Morning brief failed: ${err.message}`,
    }).catch(() => {});

    process.exit(1);
  }
}

// Try to attach Zoom transcripts to any existing Meeting brief notes
// that have a Zoom link but no transcript yet
async function fetchPendingTranscripts() {
  if (!process.env.ZOOM_ACCESS_TOKEN) return; // skip silently if not configured

  const briefsDir = path.join(VAULT, 'Meeting briefs');
  if (!fs.existsSync(briefsDir)) return;

  const notes = fs.readdirSync(briefsDir).filter(f => f.endsWith('.md'));

  for (const noteFile of notes) {
    const notePath = path.join(briefsDir, noteFile);
    const content = fs.readFileSync(notePath, 'utf8');

    // Skip notes that already have a transcript section
    if (content.includes('## Transcript') || content.includes('status: transcript-summary')) continue;

    // Look for a Zoom join URL in the note
    const zoomMatch = content.match(/https:\/\/[a-z]+\.zoom\.us\/j\/\d+[^\s]*/);
    if (!zoomMatch) continue;

    const meetingTitle = noteFile.replace(/^\d{4}-\d{2}-\d{2}\s/, '').replace('.md', '');
    console.log(`[rex] Checking Zoom transcript for: ${meetingTitle}`);

    try {
      const result = await getTranscriptForMeeting(zoomMatch[0]);

      if (result.status === 'ok') {
        const summary = await summariseTranscript(result.vtt, meetingTitle);

        // Append transcript summary to the note
        const updated = content
          .replace('status: upcoming', 'status: transcript-summary')
          .trimEnd() + `\n\n---\n\n## Transcript Summary\n\n${summary}\n`;

        fs.writeFileSync(notePath, updated, 'utf8');
        console.log(`[rex] Transcript added to: ${noteFile}`);

        await slack.chat.postMessage({
          channel: process.env.SLACK_USER_ID,
          text: `> [!rex] **Rex here.** Transcript ready for *${meetingTitle}*:\n\n${summary}`,
        });
      } else if (result.status === 'processing') {
        console.log(`[rex] Recording still processing for: ${meetingTitle}`);
      }
    } catch (err) {
      console.error(`[rex] Transcript fetch failed for ${meetingTitle}:`, err.message);
    }
  }
}

run();
