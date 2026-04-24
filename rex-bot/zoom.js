require('dotenv').config({ path: `${__dirname}/.env` });
const https = require('https');
const Anthropic = require('@anthropic-ai/sdk');

// Extract the numeric meeting ID from any Zoom join URL
function extractMeetingId(joinUrl) {
  if (!joinUrl) return null;
  const match = joinUrl.match(/zoom\.us\/j\/(\d+)/);
  return match ? match[1] : null;
}

// Generic HTTPS GET with redirect following
function httpsGet(url, headers = {}) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const req = https.request(
      { hostname: parsed.hostname, path: parsed.pathname + parsed.search, method: 'GET', headers },
      (res) => {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
          return resolve(httpsGet(res.headers.location, headers));
        }
        let body = '';
        res.on('data', chunk => { body += chunk; });
        res.on('end', () => resolve({ status: res.statusCode, body }));
      }
    );
    req.on('error', reject);
    req.end();
  });
}

// Fetch the transcript VTT for a meeting given its Zoom join URL
async function getTranscriptForMeeting(joinUrl) {
  const token = process.env.ZOOM_ACCESS_TOKEN;
  if (!token) throw new Error('ZOOM_ACCESS_TOKEN not set in .env');

  const meetingId = extractMeetingId(joinUrl);
  if (!meetingId) throw new Error(`Could not extract meeting ID from: ${joinUrl}`);

  const authHeaders = {
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
  };

  const res = await httpsGet(
    `https://api.zoom.us/v2/meetings/${meetingId}/recordings`,
    authHeaders
  );

  if (res.status === 404) return { status: 'not_found', meetingId };
  if (res.status === 200 && JSON.parse(res.body).code === 3301)
    return { status: 'not_found', meetingId }; // no recording for this meeting

  if (res.status !== 200)
    throw new Error(`Zoom API error ${res.status}: ${res.body}`);

  const data = JSON.parse(res.body);
  const files = data.recording_files ?? [];

  if (!files.length) return { status: 'no_files', meetingId };

  const transcript = files.find(
    f => f.file_type === 'TRANSCRIPT' || f.recording_type === 'audio_transcript'
  );

  if (!transcript) return { status: 'no_transcript', meetingId, hasRecording: true };
  if (transcript.status !== 'completed') return { status: 'processing', meetingId };

  // Download the VTT file — Zoom accepts the token as a query param
  const vttRes = await httpsGet(`${transcript.download_url}?access_token=${token}`);

  return {
    status: 'ok',
    meetingId,
    vtt: vttRes.body,
    duration: data.duration,
    topic: data.topic,
  };
}

// Summarise a VTT transcript into structured meeting notes
async function summariseTranscript(vttContent, meetingTitle) {
  const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

  const { content } = await anthropic.messages.create({
    model: 'claude-sonnet-4-6',
    max_tokens: 1024,
    messages: [{
      role: 'user',
      content: `You are Rex, a terse meeting agent. Summarise the transcript below for the meeting "${meetingTitle}".

Output exactly this format — no preamble, no sign-off:

## Summary
2–3 sentences on what the meeting covered.

## Key decisions
- bullet

## Action items
- [ ] item — owner (if mentioned, otherwise leave blank)

## Open questions
- bullet (omit section if none)

---
Transcript (VTT):
${vttContent}`,
    }],
  });

  return content[0].text;
}

module.exports = { getTranscriptForMeeting, summariseTranscript, extractMeetingId };
