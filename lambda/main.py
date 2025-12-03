import boto3

import cgi

from email.parser import BytesParser
from email.policy import default


import base64




BUCKET_NAME = "imoveis-financiamentos-docs"


def handler(event, context):
    s3_client = boto3.client('s3')
    body = event['body']

    if event.get('isBase64Encoded', False):
        body = base64.b64decode(body)
    else:
        body = body.encode('utf-8')


    content_type = event['headers'].get('Content-Type') or event['headers'].get('content-type')


    _, pdict = cgi.parse_header(content_type)

    boundary = pdict.get("boundary")

    if not boundary:
        return {"statusCode": 400, "body": "Boundary não encontrado no multipart"}
    

    raw = (
        f"Content-Type: {content_type}\r\n\r\n".encode("utf-8")
        + body
    )


    msg = BytesParser(policy=default).parsebytes(raw)

    uploaded_files = []

    for part in msg.iter_parts():
        disposition = part.get("Content-Disposition")
        if not disposition:
            continue


        params = dict(part.get_params(header="Content-Disposition"))
        filename = params.get("filename")


        if filename:
            file_bytes = part.get_payload(decode=True)
            file_type = part.get_content_type()


            s3_client.put_object(
                Bucket=BUCKET_NAME,
                Key=filename,
                Body=file_bytes,
                ContentType=file_type
            )


            uploaded_files.append(filename)


    if not uploaded_files:
        return {"statusCode": 400, "body": "Boundary não encontrado no multipart"}


    return {
        'statusCode': 200,
        'body': f'Upload realizado com sucesso para o bucket {BUCKET_NAME}.'
    }

 

