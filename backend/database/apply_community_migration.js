require('dotenv').config();

const fs = require('fs');
const path = require('path');
const db = require('../src/config/db');

async function applyCommunityMigration() {
  try {
    const migrationSql = fs.readFileSync(path.join(__dirname, '..', 'migrations', '006_community_hub_tables.sql'), 'utf8');
    console.log('Applying Community Hub database migration...');
    await db.query(migrationSql);
    console.log('✅ Community Hub database migration applied successfully!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Failed to apply Community Hub migration:');
    console.error('  message :', error.message || '(none)');
    console.error('  code    :', error.code || '(none)');
    console.error('  detail  :', error.detail || '(none)');
    console.error('  hint    :', error.hint || '(none)');
    console.error('  where   :', error.where || '(none)');
    console.error('  stack   :', error.stack || '(none)');
    process.exit(1);
  }
}

applyCommunityMigration();
