export const handler = async (event, context) => {
  
  const data = {
    "event": event,
	  "context": context,
  };
    return { "statusCode": 200,
	    "body": JSON.stringify(data),
	    "headers": {
		    "Content-Type": "application/json"
	    }
    }

    
};
