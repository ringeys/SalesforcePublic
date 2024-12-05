@isTest
private class ConvertRecordsToCSV2Test {
    @isTest
    private static void testGenerateCSVContent() {
        List<SObject> objects = new List<SObject>{
            new Account(Name='Test1', AccountNumber='3445556676'), 
            new Account(Name='Test2', BillingCity='Richmond'), 
            new Account(Name='Test3')
        };
        
        Test.startTest();
        String fullCSV = ConvertRecordsToCSV2.generateCSVContent(objects, null, ConvertRecordsToCSV2.CSVParseType.ALL, false);
        Test.stopTest();
        
        List<String> rows = fullCSV.split('\n');
        System.assertEquals(4, rows.size());
        
        System.assertEquals('Name,AccountNumber,BillingCity', rows[0]);
        System.assertEquals('Test1,3445556676,', rows[1]);  // Note the trailing comma
        System.assertEquals('Test2,,Richmond', rows[2]);
        System.assertEquals('Test3,,', rows[3]);
    }

    //@isTest The GROUPBY LastName causes a test failure on orgs with Shield Encryption turned on, so disabling this test
    private static void testGenerateCSVContentListedFields() {
        Account account = new Account(Name='Linked Account');
        insert account;
        
    Contact contact1 = new Contact(LastName='Test1');
        Contact contact2 = new Contact(LastName='Test2', Email='abc@gmail.com');
        Contact contact3 = new Contact(LastName='Test3', Email='abc@gmail.com', FirstName='Jonny');
        insert new List<Contact>{contact1, contact2, contact3};
        
        contact2.AccountId = account.Id;
        // Testing Note: add your own custom field here to validate custom relationships
        // contact2.Related_Contact__c = contact1.Id;
        update contact2;

        List<Contact> contacts = [Select FirstName, LastName, Email, Account.Name from Contact];

        Test.startTest();
        String allFields = ConvertRecordsToCSV2.generateCSVContent(contacts, null, ConvertRecordsToCSV2.CSVParseType.ALL, false);
        String fullCSV = ConvertRecordsToCSV2.generateCSVContent(contacts, new List<String>{'LastName','Email','Account.Name'}, ConvertRecordsToCSV2.CSVParseType.ALL, false);
        String csv_CaseSensitive = ConvertRecordsToCSV2.generateCSVContent(contacts, new List<String>{'lastName','email','Account.Name'}, ConvertRecordsToCSV2.CSVParseType.ALL, false);
        Test.stopTest();
        List<String> rows = fullCSV.split('\n');
        System.assertEquals(4, rows.size());

        System.assertEquals(3, rows[0].split(',').size(), 'Full row text: ' + rows[0]);
        System.assertEquals('LastName,Email,Account.Name', rows[0]);

        System.assertEquals('Test1,,', rows[1]);
        System.assertEquals('Test2,abc@gmail.com,Linked Account', rows[2]);
        System.assertEquals('Test3,abc@gmail.com,', rows[3]);
        
        List<String> rows2 = csv_CaseSensitive.split('\n');
        System.assertEquals('lastName,email,Account.Name', rows2[0]);
        System.assertEquals('Test2,abc@gmail.com,Linked Account', rows2[2]);
        
        List<String> rows3 = allFields.split('\n');
        System.assertEquals('LastName,Id,Email,AccountId,FirstName', rows3[0]);
    }

    @isTest
    private static void testGenerateCSVContentAggregateResult() {
        
        Contact contact1 = new Contact(LastName='Test', FirstName='Sally', LeadSource = 'Web');
        Contact contact2 = new Contact(LastName='Test1', FirstName='Mary', Email='abc@gmail.com', LeadSource = 'Web');
        Contact contact3 = new Contact(LastName='Test2', Email='abc@gmail.com', FirstName='Jonny', LeadSource = 'Social');
        insert new List<Contact>{contact1, contact2, contact3};
        update contact2;

        List<AggregateResult> contacts = [Select LeadSource name from Contact GROUP BY LeadSource];
        
        Test.startTest();
        String fullCSV = ConvertRecordsToCSV2.generateCSVContent(contacts, new List<String>{'name'}, ConvertRecordsToCSV2.CSVParseType.ALL, false);
        String unnamed = ConvertRecordsToCSV2.generateCSVContent(contacts, null, ConvertRecordsToCSV2.CSVParseType.ALL, false);
        Test.stopTest();
        
        List<String> rows = fullCSV.split('\n');
        System.assertEquals(3, rows.size(), 'Full text: ' + fullCSV);
        System.assertEquals(true, rows.contains('name'));
        System.assertEquals(true, rows.contains('Web'));
        System.assertEquals(true, rows.contains('Social'));
             
          
        List<String> rows2 = unnamed.split('\n');
        System.assertEquals(3, rows2.size(), 'Full text: ' + unnamed);
        System.assertEquals(true, rows2.contains('name'));
        System.assertEquals(true, rows2.contains('Web'));
        System.assertEquals(true, rows2.contains('Social'));
    }
    
    @isTest 
    private static void testAggregateResultCount() {
        List <Account> objects = new List<Account>{new Account(Name='Test1', AccountNumber='3445556676', Type='Prospect'), new Account(Name='Test2', BillingCity='Richmond', Type='Prospect'), new Account(Name='Test3', Type='Other')};
        insert objects;

        List<AggregateResult> count = [SELECT count(Id) NumberOfAccounts, Type FROM Account WHERE Type != null Group by Type];
        
        String aggrResult = ConvertRecordsToCSV2.generateCSVContent(count, null, ConvertRecordsToCSV2.CSVParseType.ALL, false);

        List<String> rows = aggrResult.split('\n');
        System.assertEquals(3, rows.size(), 'Full text: ' + aggrResult);
        
        List<String> headers = rows[0].split(',');
        System.assertEquals(2, headers.size(), 'Full text: ' + headers);
        System.assertEquals('NumberOfAccounts', headers[0]);
        System.assertEquals('Type', headers[1]);
    }
    
    @isTest
    private static void testFullAction() {
        // Create test contacts with only required fields
        Contact contact1 = new Contact(LastName='Test1');
        insert contact1;
        
        Test.startTest();
        
        // Query with minimal fields
        List<Contact> contacts = [SELECT Id, LastName FROM Contact];
        
        ConvertRecordsToCSV2.Inputs input = new ConvertRecordsToCSV2.Inputs();
        input.recordCollection = contacts;
        input.documentTitle = 'Test';
        input.fieldsCollection = new List<String>{'LastName'};
        input.useFieldLabels = false;  // Add this line
        
        // Test Synchronously
        ConvertRecordsToCSV2.Outputs syncOutput = ConvertRecordsToCSV2.generateCSV(
            new List<ConvertRecordsToCSV2.Inputs>{input}
        )[0];
        
        System.assert(syncOutput.contentDocumentId != null);
        System.assert(syncOutput.contentVersionId != null);
        System.assert(syncOutput.contentDocumentLinks.size() == 0);
        
        // Test Asynchronously with a new input
        ConvertRecordsToCSV2.Inputs asyncInput = new ConvertRecordsToCSV2.Inputs();
        asyncInput.recordCollection = contacts;
        asyncInput.documentTitle = 'Test Async';
        asyncInput.fieldsCollection = new List<String>{'LastName'};
        asyncInput.useFieldLabels = false;  // Add this line
        asyncInput.executeAsyncIdentifier = 'uniqueID';
        
        ConvertRecordsToCSV2.Outputs asyncOutput = ConvertRecordsToCSV2.generateCSV(
            new List<ConvertRecordsToCSV2.Inputs>{asyncInput}
        )[0];
        
        System.assert(asyncOutput.contentDocumentId == null);
        System.assert(asyncOutput.contentVersionId == null);
        System.assert(asyncOutput.contentDocumentLinks == null);
        System.assertEquals(1, asyncOutput.asyncJobIds.size());
        
        Test.stopTest();
    }
    
    @isTest
    private static void testFullActionAggrResult() {
        List <Account> objects = new List<Account>{new Account(Name='Test1', AccountNumber='3445556676', Type='Prospect'), new Account(Name='Test2', BillingCity='Richmond', Type='Prospect'), new Account(Name='Test3', Type='Other')};
        insert objects;

        List<AggregateResult> count = [SELECT count(Id) NumberOfAccounts, Type FROM Account WHERE Type != null Group by Type];
        ConvertRecordsToCSV2.Inputs input = new ConvertRecordsToCSV2.Inputs();
        input.recordCollection = count;
        input.documentTitle = 'Test';
        
        // Test Synchronously
        ConvertRecordsToCSV2.Outputs syncOutput = ConvertRecordsToCSV2.generateCSV(new List<ConvertRecordsToCSV2.Inputs>{input})[0];
        System.assert(syncOutput.contentDocumentId != null);
        System.assert(syncOutput.contentVersionId != null);
        System.assert(syncOutput.contentDocumentLinks.size() == 0);
    }

    @isTest
    private static void testGenerateDocument() {
        String csvContent = 'this, this, this, this, this \n';

        Account account = new Account(Name='Test');
        insert account;

        Test.startTest();
        ConvertRecordsToCSV2.Outputs result = ConvertRecordsToCSV2.generateDocument(new List<String>{account.Id}, 'MyDoc', 'V', 'ALlUsers', csvContent);
        Test.stopTest();

        System.assert(result.contentDocumentId != null);
        System.assert(result.contentVersionId != null);
        System.assert(result.contentDocumentLinks.size() == 1);
        System.assert(result.contentDocumentLinks[0] != null);
    }

    @isTest
    private static void testGenearteDocumentNoLinks() {
        String csvContent = 'this, this, this, this, this \n';
    
        Test.startTest();
        ConvertRecordsToCSV2.Outputs result = ConvertRecordsToCSV2.generateDocument(null, 'MyDoc', 'V', 'AllUsers', csvContent);
        Test.stopTest();

        System.assert(result.contentDocumentId != null);
        System.assert(result.contentVersionId != null);
        System.assert(result.contentDocumentLinks.size() == 0);
    }
}
