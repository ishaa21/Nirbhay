require('dotenv').config();
const db = require('./src/config/db');
const fs = require('fs');

async function main() {
  // Run migration — split by semicolon and execute each statement
  const migrationFiles = ['./migrations/004_journey_tables.sql', './migrations/005_journey_deviation_alert.sql'];
  const sql = migrationFiles
    .map((f) => fs.readFileSync(f, 'utf8'))
    .join('\n');
  const statements = sql.split(';').map(s => s.trim()).filter(s => s.length > 0 && !s.startsWith('--'));
  
  for (const stmt of statements) {
    try {
      await db.query(stmt);
      console.log('OK:', stmt.slice(0, 60).replace(/\n/g, ' ') + '...');
    } catch (e) {
      if (e.message.includes('already exists')) {
        console.log('SKIP (exists):', stmt.slice(0, 60).replace(/\n/g, ' '));
      } else {
        console.error('ERROR:', e.message, '\nSQL:', stmt.slice(0, 80));
      }
    }
  }

  // Verify tables
  const result = await db.query(
    "SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('journeys','journey_locations')"
  );
  console.log('\nTables created:', result.rows.map(r => r.table_name));
  process.exit(0);
}

main().catch(e => { console.error(e); process.exit(1); });
