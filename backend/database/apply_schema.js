require('dotenv').config();
const fs = require('fs');
const path = require('path');
const db = require('../src/config/db');

async function applySchema() {
  try {
    const schemaSql = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
    console.log('Applying database schema...');
    await db.query(schemaSql);
    console.log('✅ Database schema applied successfully to PostgreSQL!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Failed to apply database schema:', error);
    process.exit(1);
  }
}

applySchema();
