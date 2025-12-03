import boto3

import base64

from requests_toolbelt.multipart import decoder


BUCKET_NAME = "imoveis-financiamentos-docs"


def handler(event, context):
    s3_client = boto3.client('s3')
    body = event['body']

    if event.get('isBase64Encoded', False):
        body = base64.b64decode(body)
    else:
        body = body.encode('utf-8')


    content_type = event['headers'].get('Content-Type') or event['headers'].get('content-type')

    multipart_data = decoder.MultipartDecoder(body, content_type)


    file_content = None
    file_type = None
    file_name = None


    for part in multipart_data.parts:
        content_disposition = part.headers.get(b'Content-Disposition', b'').decode('utf-8')

        if "filename=" in content_disposition:
            file_content = part.content
            file_type = part.headers.get(b'Content-Type', b'application/octet-stream').decode('utf-8')

            file_name = content_disposition.split("filename=")[1].strip().strip('"')

    if file_content is None:
        return {
            'statusCode': 400,
            'body': 'No file found in the request.'
        }
    


    s3_client.put_object(
        Bucket=BUCKET_NAME,
        Key=file_name,
        Body=file_content,
        ContentType=file_type
    )


    return {
        'statusCode': 200,
        'body': f'File {file_name} uploaded successfully to bucket {BUCKET_NAME}.'
    }

 
