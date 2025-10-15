const express = require('express');
const { MongoClient, ObjectId } = require('mongodb');
const app = express();
const port = process.env.PORT || 3000;

const mongoUri = process.env.MONGO_URI || 'mongodb://mongo-transactions:27017';
const dbName = process.env.DB_NAME || 'transactions_db';

app.use(express.json());

// Health
app.get('/health', async (req, res) => {
  try {
    const client = new MongoClient(mongoUri);
    await client.connect();
    await client.db(dbName).command({ ping: 1 });
    await client.close();
    res.json({ status: 'ok' });
  } catch (e) {
    res.status(500).json({ status: 'degraded', error: e.message });
  }
});

// Simple fetch-by-user route
app.get('/api/transactions/by-user/:userId', async (req, res) => {
  const userId = req.params.userId;
  if (!userId) return res.status(400).json({ error: 'userId required' });
  let client;
  try {
    client = new MongoClient(mongoUri);
    await client.connect();
    const col = client.db(dbName).collection('transactions');
    const txs = await col.find({ user_id: userId }).sort({ timestamp: 1 }).toArray();
    res.json(txs);
  } catch (err) {
    console.error('Error:', err);
    res.status(500).json({ error: 'Server Error', details: err.message });
  } finally {
    if (client) await client.close();
  }
});

app.listen(port, () => {
  console.log(`Transactions service running on http://0.0.0.0:${port}`);
});
