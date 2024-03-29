global with sharing class SalesHD_Unit {

	public Account_Unit__c thisUnit {get; set;}

	private static Id currentUser = UserInfo.getUserId();

	private static Map<String, String> unitContactsMap = new Map<String, String>{
		'Nurse Manager'=>'Nursing',
		'Registered Nurse'=>'Nursing',
		'Educator'=>'Nursing',
		'Navigator'=>'Nursing',
		'Nurse'=>'Nursing',
		'Nurse Supervisor'=>'Nursing',
		'Wound Care Coordinator'=>'Nursing',
		'Case Manager'=>'Nursing',
		'Case Management Manager'=>'Nursing',
		'Social Worker'=>'Nursing',
		'Social worker'=>'Nursing',
		'Social Worker Manager'=>'Nursing',
		'Respiratory Therapist'=>'Nursing',
		'Case Manager'=>'Nursing',

		'Respiratory Therapist Director'=>'Director',
		'Unit Medical Director'=>'Director',

		'Nurse Practitioner'=>'Provider',
		'Physician Assistant'=>'Provider',
		'Director of Critical Care (MD)'=>'Provider',
		'Hospitalist'=>'Provider',
		'Intensivist'=>'Provider',
		'Palliative Care Physician'=>'Provider',
		'Other MDs (IM, Pulm, ID, etc.)'=>'Provider',
		'Fellow'=>'Provider',
		'Physician'=>'Provider'
	};

	// private Account_Unit__c acctUnit = [select Id from Account_Unit__c where Id = :ApexPages.currentPage().getParameters().get('id')];
	public SalesHD_Unit(ApexPages.StandardController stdController) {
		// this.acctUnit = (Account_Unit__c)stdController.getRecord();
		thisUnit = (Account_Unit__c)stdController.getRecord();
	}

	@RemoteAction global static String getNotes(Id unitId){
		List<Id> noteDocumentIds = new List<Id>();
		for(ContentDocumentLink cdl : [select ContentDocumentId from ContentDocumentLink where LinkedEntityId=:unitId]){
			noteDocumentIds.add(cdl.ContentDocumentId);
		}
		return JSON.serializePretty([select Id, Title, TextPreview from ContentNote where Id =: noteDocumentIds]);
	}

	@RemoteAction global static void deleteNote(Id noteId){
		try{
			ContentNote n = [select Id from ContentNote where Id=:noteId limit 1];
			delete n;
		}catch(DmlException ex){
			ApexPages.addMessages(ex);
		}
	}

	@RemoteAction global static void saveNote(Id unitId, String noteInput, String titleInput){
		ContentNote n = new ContentNote(Title=titleInput, Content=blob.valueOf(noteInput));
		insert n;
		ContentDocumentLink cdl = new ContentDocumentLink(LinkedEntityId=unitId, ContentDocumentId=n.Id, ShareType='V');
		insert cdl;
	}

	@RemoteAction global static String getFavoriedContacts(){
		return JSON.serializePretty([select Contact__r.Name from Contact_Team__c where Contact__r.Status__c='Active' and User__c =: currentUser]);
	}

	@RemoteAction global static List<Contact> saveContact(Id unitId, Id contactId, String title){
		List<Contact> updateContacts = new List<Contact>();
		for(Contact c : [select Title__c, MailingPostalCode from Contact where Id=:contactId]){
			c.Title__c = title;
			if(c.MailingPostalCode != null){
				if(c.MailingPostalCode.length()==9){
					c.MailingPostalCode = c.MailingPostalCode.left(5) + '-' + c.MailingPostalCode.right(4);
				} else if(c.MailingPostalCode.length()!=10 && c.MailingPostalCode.length()!=5){
					c.MailingPostalCode = null;
				}
			}
			updateContacts.add(c);
		}
		update updateContacts;
		List<Account_Unit_Contact__c> auc = [select id from Account_Unit_Contact__c where Account_Unit__c=:unitId and Contact__c=:contactId];
		if(auc.isEmpty()) insert new Account_Unit_Contact__c(Account_Unit__c=unitId, Contact__c=contactId);
		return updateContacts;
	}

	@RemoteAction global static String getEncounters(Id unitId){

		List<Event> pastEvents = new List<Event>();
		List<Event> futureEvents = new List<Event>();

		pastEvents = [select id, subject, startDateTime, SalesHD_Complete__c, description,
		who.name, SalesHD_Call_Objective__c, what.Name, SalesHD_Account_Unit__r.Unit__r.Name,
		SalesHD_Open_Ended_Questions__c, createdby.Name, createdby.SmallPhotoUrl, ActivityDate from event
		where SalesHD_Account_Unit__c=:unitId and activityDateTime<TODAY order by activityDateTime desc limit 100 ];

		futureEvents = [select id, subject, startDateTime, SalesHD_Complete__c, description,
		who.name, SalesHD_Call_Objective__c, SalesHD_Open_Ended_Questions__c, what.Name,
		SalesHD_Account_Unit__r.Unit__r.Name, createdby.Name, createdby.SmallPhotoUrl, ActivityDate from event
		where SalesHD_Account_Unit__c=:unitId and activityDateTime>=TODAY order by activityDateTime desc limit 100];

		return '{"pastEvents" : '+JSON.serialize(pastEvents)+', "futureEvents" : '+JSON.serialize(futureEvents)+'}';
	}

	@RemoteAction global static String getContacts(Id unitId){
		Map<String, List<Account_Unit_Contact__c>> contacts = new Map<String, List<Account_Unit_Contact__c>>();

		for(Account_Unit_Contact__c auc : [select Contact__r.Title__c, Contact__r.Name, Contact__r.Id, Contact__r.HD_Specialties__c
		from Account_Unit_Contact__c where Account_Unit__c=:unitId order by Contact__r.Title__c]){
			if(unitContactsMap.containsKey(auc.Contact__r.Title__c) && contacts.containsKey(unitContactsMap.get(auc.Contact__r.Title__c))){
				contacts.get(unitContactsMap.get(auc.Contact__r.Title__c)).add(auc);
			} else{
				if(unitContactsMap.containsKey(auc.Contact__r.Title__c)) contacts.put(unitContactsMap.get(auc.Contact__r.Title__c), new List<Account_Unit_Contact__c>{auc});
			}
		}

		return JSON.serializePretty(contacts);

	}

}
