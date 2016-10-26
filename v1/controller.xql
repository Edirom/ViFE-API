xquery version "3.1" encoding "UTF-8";
declare namespace request="http://exist-db.org/xquery/request";
declare namespace response="http://exist-db.org/xquery/response";
declare namespace json-output="http://www.w3.org/2010/xslt-xquery-serialization";

(: Change this line to point at your local api module :)
import module namespace api="http://xquery.weber-gesamtausgabe.de/modules/dev" at "../../modules/dev/dev.xqm";

declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;

declare variable $local:model as map() := map { 
    'exist:path' := $exist:path, 
    'exist:resource' := $exist:resource, 
    'exist:controller' := $exist:controller, 
    'exist:prefix' := $exist:prefix 
};

declare function local:serialize-json($model as item()*) {
    let $serializationParameters := ('method=text', 'media-type=application/json', 'encoding=utf-8')
    return 
        response:stream(
            serialize($model, 
                <json-output:serialization-parameters>
                    <json-output:method>json</json-output:method>
                </json-output:serialization-parameters>
            ), 
            string-join($serializationParameters, ' ')
        )      
};

let $response :=
    try { function-lookup(xs:QName('api:' || $exist:resource), 1)($local:model) }
    catch * { map {'code' := 404, 'message' := $err:description, 'fields' := 'Error Code: ' ||  $err:code} }
    
return 
    local:serialize-json($response)
