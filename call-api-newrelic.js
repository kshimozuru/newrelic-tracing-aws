#!/usr/bin/env node

// New Relic Tracing AWS - Shell-like API Gateway Caller with New Relic Entity
// This version includes New Relic Agent for APM Entity visibility

require('dotenv').config({ path: './.env' });
require('newrelic');

const axios = require('axios');
const { spawn } = require('child_process');
const { program } = require('commander');

// New Relic Entity Name configuration
const ENTITY_NAME = process.env.NEW_RELIC_APP_NAME || 'newrelic-tracing-shell-client';

console.log(`🌟 New Relic Shell Client - Entity: ${ENTITY_NAME}`);

// Load environment variables
function loadEnvironment() {
    const requiredVars = ['NEW_RELIC_LICENSE_KEY'];
    const missing = requiredVars.filter(v => !process.env[v]);
    
    if (missing.length > 0) {
        console.error('❌ Missing required environment variables:', missing.join(', '));
        process.exit(1);
    }
    
    console.log('✅ Environment variables loaded');
    return true;
}

// Get API Gateway URL
async function getApiUrl() {
    // Try Terraform output first
    if (require('fs').existsSync('./terraform')) {
        try {
            const { stdout } = await new Promise((resolve, reject) => {
                const terraform = spawn('terraform', ['output', '-raw', 'api_gateway_url'], {
                    cwd: './terraform',
                    stdio: 'pipe'
                });
                
                let stdout = '';
                terraform.stdout.on('data', (data) => stdout += data);
                terraform.on('close', (code) => {
                    if (code === 0) resolve({ stdout: stdout.trim() });
                    else reject(new Error(`Terraform failed with code ${code}`));
                });
            });
            
            if (stdout) {
                console.log('✅ API Gateway URL from Terraform:', stdout);
                return stdout;
            }
        } catch (error) {
            console.log('⚠️  Terraform not available, using .env');
        }
    }
    
    const url = process.env.API_GATEWAY_URL;
    if (!url) {
        console.error('❌ API Gateway URL not found in environment or Terraform');
        process.exit(1);
    }
    
    console.log('✅ API Gateway URL from .env:', url);
    return url;
}

// Generate W3C compatible trace ID
function generateTraceId() {
    const timestamp = Math.floor(Date.now() / 1000);
    const timestampHex = timestamp.toString(16).padStart(8, '0');
    
    // Generate 12 random bytes (24 hex chars)
    const randomBytes = require('crypto').randomBytes(12);
    const randomHex = randomBytes.toString('hex');
    
    return (timestampHex + randomHex).substring(0, 32);
}

// Send request with New Relic tracing
async function sendRequest(message, additionalData = {}) {
    const newrelic = require('newrelic');
    
    return await newrelic.startBackgroundTransaction('shell-api-call', 'Custom', async () => {
        try {
            const traceId = generateTraceId();
            const timestamp = new Date().toISOString();
            const apiUrl = await getApiUrl();
            
            // Set New Relic transaction attributes
            newrelic.addCustomAttributes({
                'shell.message': message,
                'shell.trace_id': traceId,
                'shell.api_url': apiUrl,
                'shell.timestamp': timestamp
            });
            
            console.log('🚀 Sending request to API Gateway...');
            console.log('📝 Message:', message);
            console.log('🔍 Trace ID:', traceId);
            console.log('🎯 URL:', apiUrl);
            console.log('🏷️  New Relic Entity:', ENTITY_NAME);
            
            const requestData = {
                message,
                timestamp,
                source: 'shell-newrelic-client',
                traceId,
                ...additionalData
            };
            
            console.log('📄 Request data:', JSON.stringify(requestData, null, 2));
            
            const response = await axios.post(apiUrl, requestData, {
                headers: {
                    'Content-Type': 'application/json',
                    'User-Agent': `NewRelic-Shell-Client/1.0 (Entity: ${ENTITY_NAME})`,
                    'X-Trace-Id': traceId,
                    'X-New-Relic-Entity': ENTITY_NAME
                },
                timeout: 30000
            });
            
            // Record successful response in New Relic
            newrelic.addCustomAttributes({
                'response.status': response.status,
                'response.message_id': response.data.messageId,
                'response.api_trace_id': response.data.traceId
            });
            
            console.log('📊 Response:');
            console.log('HTTP Status:', response.status);
            console.log('✅ Success!');
            console.log(JSON.stringify(response.data, null, 2));
            
            if (response.data.traceId) {
                console.log('\n🔗 Trace Information:');
                console.log('Shell Trace ID:', traceId);
                console.log('API Gateway Trace ID:', response.data.traceId);
                console.log('New Relic Entity:', ENTITY_NAME);
                console.log('\n💡 Check New Relic APM Dashboard for entity visibility');
            }
            
            return response.data;
            
        } catch (error) {
            console.error('❌ Request failed:', error.message);
            
            // Record error in New Relic
            newrelic.noticeError(error, {
                'shell.error_type': 'api_call_failed',
                'shell.error_message': error.message
            });
            
            if (error.response) {
                console.error('Response status:', error.response.status);
                console.error('Response data:', error.response.data);
            }
            
            throw error;
        }
    });
}

// CLI Program setup
program
    .name('call-api-newrelic')
    .description('New Relic integrated Shell API Gateway caller')
    .version('1.0.0');

program
    .command('send')
    .description('Send a traced request with New Relic entity visibility')
    .option('-m, --message <message>', 'Message to send', 'Hello from New Relic Shell')
    .option('-d, --data <data>', 'Additional JSON data to send')
    .action(async (options) => {
        try {
            loadEnvironment();
            
            let additionalData = {};
            if (options.data) {
                try {
                    additionalData = JSON.parse(options.data);
                } catch (e) {
                    console.warn('⚠️  Invalid JSON data provided, ignoring:', options.data);
                }
            }
            
            await sendRequest(options.message, additionalData);
            console.log('\n🎉 Request completed successfully!');
            
        } catch (error) {
            console.error('\n💥 Operation failed:', error.message);
            process.exit(1);
        }
    });

program
    .command('test')
    .description('Test New Relic integration and entity visibility')
    .action(async () => {
        try {
            loadEnvironment();
            
            const newrelic = require('newrelic');
            console.log('🧪 Testing New Relic integration...');
            console.log('Entity Name:', ENTITY_NAME);
            console.log('Agent State:', newrelic.agent ? 'LOADED' : 'NOT_LOADED');
            
            // Create a test transaction
            await newrelic.startBackgroundTransaction('shell-test', 'Custom', async () => {
                newrelic.addCustomAttributes({
                    'test.type': 'entity_visibility',
                    'test.entity_name': ENTITY_NAME,
                    'test.timestamp': new Date().toISOString()
                });
                
                console.log('✅ New Relic test transaction created');
                console.log('💡 Check New Relic APM for entity:', ENTITY_NAME);
            });
            
        } catch (error) {
            console.error('❌ Test failed:', error.message);
            process.exit(1);
        }
    });

// Show help if no arguments
if (process.argv.length <= 2) {
    program.help();
}

program.parse();