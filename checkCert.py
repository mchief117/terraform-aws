import socket
import ssl
import datetime
import json
import uuid
# import logger

GET_RAW_PATH = "/live/ssl_check"

url_id = ""

def checkCert_handler(event, context):
    print(event)
    if event['rawPath'] == GET_RAW_PATH:
        print("Checking SSL Cert Validity")
        url_id = event['queryStringParameters']['url_id']
        print("URL is " + url_id)
        #return url_id
        buffer_days = 14

        hostname = url_id
        #ssl_expires_in(hostname)
        """Check if `hostname` SSL cert expires is within `buffer_days`.

        Raises `AlreadyExpired` if the cert is past due
        """
        print('Pre SSL Valid Time Remaining')

        """Get the number of days left in a cert's lifetime."""
        ##expires = ssl_expiry_datetime(hostname)
        ssl_date_fmt = r'%b %d %H:%M:%S %Y %Z'

        context = ssl.create_default_context()
        conn = context.wrap_socket(
            socket.socket(socket.AF_INET),
            server_hostname=hostname,
        )
        # 3 second timeout because Lambda has runtime limitations
        conn.settimeout(3.0)

        conn.connect((hostname, 443))
        ssl_info = conn.getpeercert()
        # parse the string from the certificate into a Python datetime object
        expires = datetime.datetime.strptime(ssl_info['notAfter'], ssl_date_fmt)

        # logger.debug(
        #     "SSL cert for %s expires at %s",
        #     hostname, expires.isoformat()
        # )
        #return expires - datetime.datetime.utcnow()
        #remaining = ssl_valid_time_remaining(hostname)

        remaining = expires - datetime.datetime.utcnow()

        print('Post SSL Valid Time Remaining')

        # if the cert expires in less than two weeks, we should reissue it
        if remaining < datetime.timedelta(days=0):
            # cert has already expired - uhoh!
            raise AlreadyExpired("Cert expired %s days ago" % remaining.days)
        else:
            # everything is fine
            ssl_valid = "SSL Certificate is still valid"
            return ssl_valid
        
        
    else:
        #Possible other requests i.e. POST Delete
        print("Wrong API Request")

