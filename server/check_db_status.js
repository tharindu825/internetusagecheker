const { getAllClients, getInactiveClients } = require('./db');
(async () => {
    try {
        const active = await getAllClients();
        const inactive = await getInactiveClients();
        console.log('--- Active Clients ---');
        active.forEach(c => console.log(`${c.hostname} (ID: ${c.id}) is ACTIVE`));
        console.log('\n--- Inactive (Removed) Clients ---');
        inactive.forEach(c => console.log(`${c.hostname} (ID: ${c.id}) is INACTIVE`));
    } catch (e) {
        console.error(e);
    }
})();
