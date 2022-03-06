ruleset wovyn_base {
    meta {
        use module sensor_profile alias sp
        use module io.picolabs.subscription alias subscription
        use module wovyn_subscription alias ws
        with 
            accountSID = meta:rulesetConfig{"account_sid"}
            authToken = meta:rulesetConfig{"auth_token"}
        shares __testing
    }
    global {
        temperature_threshold = 80
        myPhone = "+14433590071"
        myTwilio = "+14435966495"
      }

    rule process_heartbeat {
        select when wovyn heartbeat
        pre {
          genericThing = event:attr("genericThing") => event:attrs.klog("attrs") | none
        }
        fired {
            raise wovyn event "new_temperature_reading"
            attributes {
                "temperature": event:attr("genericThing").get(["data","temperature"]).head().get(["temperatureF"]),
                "timestamp": event:time
            }
        }
    }
    rule find_high_temps {
        select when wovyn new_temperature_reading
        pre {
            temperature = event:attr("temperature").klog("attrs")
            temperature_threshold = sp:sensor_profile()["threshold"];
        }
        fired {
            raise wovyn event "threshold_violation"
            attributes {
                "temperature": event:attr("temperature"),
                "timestamp": event:attr("timestamp")
            } if temperature > temperature_threshold
        }
    }
    rule threshold_notification {
        select when wovyn threshold_violation 
        foreach subscription:established() setting (sub)
            event:send({
                "eci": sub{"Tx"},
                "domain":"wovyn", 
                "type":"threshold_violation",
                "attrs": {
                    "temperature": event:attr("temperature") 
                }
        })
    }
    
}