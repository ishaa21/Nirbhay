require('dotenv').config();

const fs = require('fs');
const path = require('path');
const db = require('../src/config/db');

async function applyTimerMigration() {
  try {
    const migrationSql = fs.readFileSync(path.join(__dirname, 'migrate_safety_timer.sql'), 'utf8');
    console.log('Applying Safety Timer database migration...');
    await db.query(migrationSql);
    console.log('✅ Safety Timer database migration applied successfully!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Failed to apply Safety Timer migration:');
    console.error('  message :', error.message  || '(none)');
    console.error('  code    :', error.code     || '(none)');
    console.error('  detail  :', error.detail   || '(none)');
    console.error('  hint    :', error.hint     || '(none)');
    console.error('  where   :', error.where    || '(none)');
    console.error('  stack   :', error.stack    || '(none)');
    process.exit(1);
  }
}

applyTimerMigration();
