const { App } = require('@slack/bolt');
const Anthropic = require('@anthropic-ai/sdk');
const fs = require('fs');
const path = require('path');

// Load Rex's personality from SKILL.md — single source of truth
const skillRaw = fs.readFileSync(
  path.join(__dirname, '../skills/rex/SKILL.md'),
  'utf8'
);
// Strip YAML frontmatter
const systemPrompt = skillRaw.replace(/^---[\s\S]*?---\n/, '').trim();

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

const app = new App({
  token: process.env.SLACK_BOT_TOKEN,
  appToken: process.env.SLACK_APP_TOKEN,
  socketMode: true,
});

// Per-channel conversation history (resets on restart — intentional for a personal tool)
const conversations = new Map();

async function askRex(channelId, userMessage) {
  if (!conversations.has(channelId)) {
    conversations.set(channelId, []);
  }

  const history = conversations.get(channelId);
  history.push({ role: 'user', content: userMessage });

  const response = await anthropic.messages.create({
    model: 'claude-sonnet-4-6',
    max_tokens: 1024,
    system: systemPrompt,
    messages: history.slice(-20), // keep last 20 turns
  });

  const reply = response.content[0].text;
  history.push({ role: 'assistant', content: reply });

  return reply;
}

// Handle direct messages
app.message(async ({ message, say }) => {
  // Ignore bot messages, edits, deletes
  if (message.subtype || message.bot_id) return;

  try {
    const reply = await askRex(message.channel, message.text);
    await say(reply);
  } catch (err) {
    console.error('Error calling Claude:', err);
    await say("Something went wrong on my end. Try again.");
  }
});

// Handle @rex mentions in channels
app.event('app_mention', async ({ event, say }) => {
  const text = event.text.replace(/<@[A-Z0-9]+>/g, '').trim();
  if (!text) return;

  try {
    const reply = await askRex(event.channel, text);
    await say(reply);
  } catch (err) {
    console.error('Error calling Claude:', err);
    await say("Something went wrong on my end. Try again.");
  }
});

(async () => {
  await app.start();
  console.log('Rex is online');
})();
