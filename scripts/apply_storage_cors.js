const { Storage } = require('@google-cloud/storage');
const cors = require('../cors.json');

const bucketName = 'catalogo-ja-89aae.firebasestorage.app';
const keyFilename =
  process.env.GOOGLE_APPLICATION_CREDENTIALS ||
  process.env.SERVICE_ACCOUNT_JSON ||
  'service-account-catalogo-ja-89aae.json';

async function main() {
  const storage = new Storage({ keyFilename });
  const bucket = storage.bucket(bucketName);

  await bucket.setCorsConfiguration(cors);
  const [metadata] = await bucket.getMetadata();

  console.log(`CORS aplicado no bucket ${bucketName}:`);
  console.log(JSON.stringify(metadata.cors, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
