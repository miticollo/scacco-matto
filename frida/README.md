# frida scripts

Here you can find an index of my experiments and tests with frida on iOS.

## SQLCipher

_See_ [dedicated chapter](sqlcipher/)

## xpc-tracer

This project has an [independent repo](https://github.com/miticollo/xpc-tracer).

## new contact created inside a third-party app

> :warning: I tested it only on Telegram, but it's probably that it works also on other app.

```javascript
Interceptor.attach(ObjC.classes.CNDataMapperContactStore['- executeSaveRequest:response:error:'].implementation, {
    onEnter: function (args) {
        let addressBookPeople = new ObjC.Object(args[2]).$ivars["_addedContactsByIdentifier"]; // __NSDictionaryM
        let key = addressBookPeople.keyEnumerator().nextObject();
        let contact = addressBookPeople.objectForKey_(key).objectAtIndex_(0);
        console.log(
            contact.valueForKeyPath_('givenName'),
            ' --> ',
            contact.valueForKeyPath_('phoneNumbers.value.stringValue').objectAtIndex_(0)
        );
    }
});
```