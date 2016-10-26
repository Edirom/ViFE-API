xquery version "3.1" encoding "UTF-8";
declare namespace request="http://exist-db.org/xquery/request";
declare namespace response="http://exist-db.org/xquery/response";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

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

(:~
 :  Serialize output as JSON
 :
 :  @param $response the output to be serialized
 :  @return          no return value. The output gets streamed directly to the servlet's output stream via response:stream(). 
~:)
declare function local:serialize-json($response as item()*) {
    let $serializationParameters := ('method=text', 'media-type=application/json', 'encoding=utf-8')
    let $setHeader1 := response:set-header('cache-control','max-age=0, no-cache, no-store')
    let $setHeader2 := response:set-header('pragma','no-cache')
    (:let $setHeader3 := 
        if(exists($response)) then response:set-header('ETag', util:hash($response, 'md5'))
        else ():)
    return 
        response:stream(
            serialize($response, 
                <output:serialization-parameters>
                    <output:method>json</output:method>
                </output:serialization-parameters>
            ), 
            string-join($serializationParameters, ' ')
        )      
};

(:~
 :  Serialize output as XML
 : 
 :  @param $response the output to be serialized
 :  @param $root     the name of the root element
 :  @return          an XML fragment 
~:)
declare function local:serialize-xml($response as item()*, $root as xs:string) as element() {
    element {$root} {
        for $i in $response
        return 
            typeswitch($i)
            case map() return $i?* ! local:serialize-xml($i(.), .)
            case function() as item() return <array>{ for $j in $i?* return local:serialize-xml($j, 'root')/node() }</array>
            default return $response
    }
};

(:~
 :   Try to lookup a function by requested resource 
~:)
let $lookup := function-lookup(xs:QName('api:' || $exist:resource), 1)

(:~  
 :   Create response by calling the above function 
 :   Sending one parameter to the function of type map()
 :   If $lookup is empty, return a map() with error message and code
~:)
let $response := 
    typeswitch($lookup)
    case empty() return map {'code' := 404, 'message' := 'not implemented', 'fields' := ''}
    default return 
        try { $lookup($local:model) }
        catch * { map {'code' := 404, 'message' := $err:description, 'fields' := 'Error Code: ' ||  $err:code} }

(:~
 : Check HTTP header for 'Accept' key. 
 : Browsers send a comma separated list of possible values 
~:)
let $accept-header := tokenize(request:get-header('Accept'), '[,;]')

return
    if($accept-header[.='application/xml']) then local:serialize-xml($response, if(empty($lookup)) then 'Error' else $exist:resource )
    else if($accept-header[.='application/json']) then local:serialize-json($response)
    else ()
