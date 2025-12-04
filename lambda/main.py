import boto3
import json

import base64




BUCKET_NAME = "imoveis-financiamentos-docs"


s3 = boto3.client("s3")

def handler(event, context):

    filename = event.get("filename")

    filecontent_b64 = event.get("file_content")


    decoded_file = base64.b64decode(filecontent_b64)


    try:

        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=filename,
            body=decoded_file
        )

        return {
            'statusCode': 200,
            'body': f'Upload realizado com sucesso para o bucket {BUCKET_NAME}.'
        }
    
    except Exception as e:
        return {
            'statusCode': 500,
            "body": json.dumps(f'Error uploading file: {str(e)}')
        }

 

