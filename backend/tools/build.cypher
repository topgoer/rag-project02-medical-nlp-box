// -----------------------------------------------------------------------------------------
// Concept: Update a SNOMED_G Graph Database from input CSV files which describe the changes
//          to concepts, descriptions, ISA relationships and defining relationships.
// Input Files:
//          concept_new.csv
//          descrip_new.csv
//          isa_rel_new.csv
//          defining_rel_new.csv

// NEXT STEP -- create INDEXES

CREATE CONSTRAINT FOR (c:ObjectConcept) REQUIRE c.id IS UNIQUE;
CREATE CONSTRAINT FOR (c:ObjectConcept) REQUIRE c.sctid IS UNIQUE;
   // id,sctid index created, requiring uniqueness
   // Note: Can't have "FSN is UNIQUE"" constraint, can have dups (inactive concepts)
   //      for example -- "retired procedure" is FSN of multiple inactive concepts
CREATE CONSTRAINT FOR (c:Description) REQUIRE c.id IS UNIQUE;
CREATE INDEX FOR (x:Description) ON (x.sctid);
  // need index so setting HAS_DESCRIPTION edges doesn't stall
  // there can be more than one description for the same sctid, sctid not unique, but id is unique

// ROLE_GROUP nodes.  Index needed for defining relationship assignment.
CREATE INDEX FOR (x:RoleGroup) ON (x.sctid);

// NEXT STEP -- create CONCEPT nodes

RETURN 'Creating NEW ObjectConcept nodes';
LOAD csv with headers from "file:/var/lib/neo4j/import/concept_new.csv" as line
CALL {
    with line
    CREATE (n:ObjectConcept
        { nodetype:           'concept',
          id:                 line.id,
          sctid:              line.id,
          active:             line.active,
          effectiveTime:      line.effectiveTime,
          moduleId:           line.moduleId,
          definitionStatusId: line.definitionStatusId,
          FSN:                line.FSN,
          history:            line.history} )
    
} IN TRANSACTIONS OF 200 ROWS;

// NEXT STEP -- create DESCRIPTION nodes (info from Language+Description file)
RETURN 'Creating NEW Description nodes';

LOAD csv with headers from "file:/var/lib/neo4j/import/descrip_new.csv" as line
CALL {
    with line
    CREATE (n:Description
        { nodetype:'description',
          id: line.id,
          sctid: line.sctid,
          active: line.active,
          typeId: line.typeId,
          moduleId: line.moduleId,
          descriptionType: line.descriptionType,
          id128bit: line.id128bit,
          term: line.term,
          effectiveTime: line.effectiveTime,
          acceptabilityId: line.acceptabilityId,
          refsetId: line.refsetId,
          caseSignificanceId: line.caseSignificanceId,
          languageCode: line.languageCode,
          history: line.history} )
    
} IN TRANSACTIONS OF 200 ROWS;

// NEXT STEP - create DESCRIPTION edges
RETURN 'Creating HAS_DESCRIPTION edges for new Description nodes related to ObjectConcept nodes';

LOAD csv with headers from "file:/var/lib/neo4j/import/descrip_new.csv" as line
CALL {
    with line
    MATCH (c:ObjectConcept { sctid: line.sctid }), (f:Description { id: line.id })
    MERGE (c)-[:HAS_DESCRIPTION]->(f) 
} IN TRANSACTIONS OF 200 ROWS;

// --------------------------------------------------------------------------------------
// NEXT STEP -- create ISA relationships
// --------------------------------------------------------------------------------------

RETURN 'Creating NEW ISA edges';

LOAD csv with headers from "file:/var/lib/neo4j/import/isa_rel_new.csv" as line
CALL {
    with line
    MATCH (c1:ObjectConcept { id: line.sourceId }), (c2:ObjectConcept { id: line.destinationId })
    MERGE (c1)-[:ISA { id: line.id,
                           active: line.active,
                           effectiveTime: line.effectiveTime,
                           moduleId: line.moduleId,
                           relationshipGroup: line.relationshipGroup,
                           typeId: line.typeId,
                           characteristicTypeId: line.characteristicTypeId,
                           sourceId: line.sourceId,
                           destinationId: line.destinationId,
                           history: line.history  }]->(c2)
    } IN TRANSACTIONS OF 200 ROWS;

// --------------------------------------------------------------------------------------
// NEXT STEP -- create RoleGroup nodes
// --------------------------------------------------------------------------------------
RETURN 'Creating RoleGroup nodes';
LOAD csv with headers from "file:/var/lib/neo4j/import/rolegroups.csv" as line
CALL {
    with line
    MERGE (rg:RoleGroup
        { nodetype:'rolegroup',
          sctid: line.sctid,
          rolegroup: line.rolegroup})
} IN TRANSACTIONS OF 500 ROWS;

// Add edge in 2nd step, Java memory issue
RETURN 'Creating HAS_ROLE_GROUP edges';
LOAD csv with headers from "file:/var/lib/neo4j/import/rolegroups.csv" as line
CALL {
    with line
    MATCH (c:ObjectConcept { sctid: line.sctid }), (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
    MERGE (c)-[:HAS_ROLE_GROUP]->(rg)  
} IN TRANSACTIONS OF 500 ROWS;


// --------------------------------------------------------------------------------------
// NEXT STEP -- create Defining relationships
// --------------------------------------------------------------------------------------

// FINDING_SITE defining relationships
RETURN 'NEW Defining relationships of type FINDING_SITE';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_363698007_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_363698007_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:FINDING_SITE { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// PART_OF defining relationships
RETURN 'NEW Defining relationships of type PART_OF';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_123005000_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_123005000_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:PART_OF { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// PATHOLOGICAL_PROCESS_QUALIFIER_VALUE defining relationships
RETURN 'NEW Defining relationships of type PATHOLOGICAL_PROCESS_QUALIFIER_VALUE';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_308489006_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_308489006_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:PATHOLOGICAL_PROCESS_QUALIFIER_VALUE { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// CAUSATIVE_AGENT defining relationships
RETURN 'NEW Defining relationships of type CAUSATIVE_AGENT';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_246075003_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_246075003_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:CAUSATIVE_AGENT { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// EXTENT defining relationships
RETURN 'NEW Defining relationships of type EXTENT';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_260858005_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_260858005_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:EXTENT { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// ASSOCIATED_MORPHOLOGY defining relationships
RETURN 'NEW Defining relationships of type ASSOCIATED_MORPHOLOGY';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_116676008_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_116676008_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:ASSOCIATED_MORPHOLOGY { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// METHOD defining relationships
RETURN 'NEW Defining relationships of type METHOD';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_260686004_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_260686004_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:METHOD { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// PROCEDURE_SITE defining relationships
RETURN 'NEW Defining relationships of type PROCEDURE_SITE';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_363704007_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_363704007_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:PROCEDURE_SITE { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// USING defining relationships
RETURN 'NEW Defining relationships of type USING';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_261583007_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_261583007_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:USING { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// DIRECT_MORPHOLOGY defining relationships
RETURN 'NEW Defining relationships of type DIRECT_MORPHOLOGY';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_363700003_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_363700003_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:DIRECT_MORPHOLOGY { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// OCCURRENCE defining relationships
RETURN 'NEW Defining relationships of type OCCURRENCE';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_246454002_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_246454002_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:OCCURRENCE { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// INTERPRETS defining relationships
RETURN 'NEW Defining relationships of type INTERPRETS';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_363714003_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_363714003_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:INTERPRETS { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_INTENT defining relationships
RETURN 'NEW Defining relationships of type HAS_INTENT';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_363703001_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_363703001_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_INTENT { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// COURSE defining relationships
RETURN 'NEW Defining relationships of type COURSE';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_260908002_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_260908002_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:COURSE { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_MEASURED_COMPONENT defining relationships
RETURN 'NEW Defining relationships of type HAS_MEASURED_COMPONENT';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_116678009_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_116678009_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_MEASURED_COMPONENT { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// APPROACH defining relationships
RETURN 'NEW Defining relationships of type APPROACH';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_260669005_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_260669005_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:APPROACH { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// ACCESS defining relationships
RETURN 'NEW Defining relationships of type ACCESS';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_260507000_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_260507000_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:ACCESS { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// REVISION_STATUS defining relationships
RETURN 'NEW Defining relationships of type REVISION_STATUS';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_246513007_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_246513007_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:REVISION_STATUS { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// DIRECT_SUBSTANCE defining relationships
RETURN 'NEW Defining relationships of type DIRECT_SUBSTANCE';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_363701004_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_363701004_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:DIRECT_SUBSTANCE { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// DIRECT_DEVICE defining relationships
RETURN 'NEW Defining relationships of type DIRECT_DEVICE';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_363699004_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_363699004_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:DIRECT_DEVICE { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// ASSOCIATED_FINDING defining relationships
RETURN 'NEW Defining relationships of type ASSOCIATED_FINDING';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_246090004_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_246090004_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:ASSOCIATED_FINDING { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// EPISODICITY defining relationships
RETURN 'NEW Defining relationships of type EPISODICITY';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_246456000_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_246456000_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:EPISODICITY { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// LATERALITY defining relationships
RETURN 'NEW Defining relationships of type LATERALITY';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_272741003_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_272741003_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:LATERALITY { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// SEVERITY defining relationships
RETURN 'NEW Defining relationships of type SEVERITY';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_246112005_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_246112005_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:SEVERITY { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// MEASURES defining relationships
RETURN 'NEW Defining relationships of type MEASURES';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_367346004_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_367346004_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:MEASURES { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// COMMUNICATION_WITH_WOUND defining relationships
RETURN 'NEW Defining relationships of type COMMUNICATION_WITH_WOUND';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_263535000_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_263535000_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:COMMUNICATION_WITH_WOUND { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_DEFINITIONAL_MANIFESTATION defining relationships
RETURN 'NEW Defining relationships of type HAS_DEFINITIONAL_MANIFESTATION';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_363705008_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_363705008_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_DEFINITIONAL_MANIFESTATION { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_FOCUS defining relationships
RETURN 'NEW Defining relationships of type HAS_FOCUS';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_363702006_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_363702006_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_FOCUS { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// PRIORITY defining relationships
RETURN 'NEW Defining relationships of type PRIORITY';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_260870009_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_260870009_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:PRIORITY { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// INSTRUMENTATION defining relationships
RETURN 'NEW Defining relationships of type INSTRUMENTATION';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_309824003_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_309824003_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:INSTRUMENTATION { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// TEMPORALLY_FOLLOWS defining relationships
RETURN 'NEW Defining relationships of type TEMPORALLY_FOLLOWS';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_363708005_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_363708005_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:TEMPORALLY_FOLLOWS { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// ONSET defining relationships
RETURN 'NEW Defining relationships of type ONSET';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_246100006_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_246100006_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:ONSET { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// STAGE defining relationships
RETURN 'NEW Defining relationships of type STAGE';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_258214002_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_258214002_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:STAGE { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_ACTIVE_INGREDIENT defining relationships
RETURN 'NEW Defining relationships of type HAS_ACTIVE_INGREDIENT';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_127489000_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_127489000_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_ACTIVE_INGREDIENT { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// ASSOCIATED_ETIOLOGIC_FINDING defining relationships
RETURN 'NEW Defining relationships of type ASSOCIATED_ETIOLOGIC_FINDING';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_363715002_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_363715002_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:ASSOCIATED_ETIOLOGIC_FINDING { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// ASSOCIATED_PROCEDURE defining relationships
RETURN 'NEW Defining relationships of type ASSOCIATED_PROCEDURE';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_363589002_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_363589002_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:ASSOCIATED_PROCEDURE { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// ASSOCIATED_FUNCTION defining relationships
RETURN 'NEW Defining relationships of type ASSOCIATED_FUNCTION';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_116683001_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_116683001_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:ASSOCIATED_FUNCTION { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// LOCATION defining relationships
RETURN 'NEW Defining relationships of type LOCATION';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_246267002_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_246267002_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:LOCATION { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// INDIRECT_MORPHOLOGY defining relationships
RETURN 'NEW Defining relationships of type INDIRECT_MORPHOLOGY';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_363709002_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_363709002_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:INDIRECT_MORPHOLOGY { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// COMPONENT defining relationships
RETURN 'NEW Defining relationships of type COMPONENT';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_246093002_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_246093002_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:COMPONENT { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_SPECIMEN defining relationships
RETURN 'NEW Defining relationships of type HAS_SPECIMEN';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_116686009_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_116686009_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_SPECIMEN { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_INTERPRETATION defining relationships
RETURN 'NEW Defining relationships of type HAS_INTERPRETATION';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_363713009_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_363713009_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_INTERPRETATION { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// SUBJECT_OF_INFORMATION defining relationships
RETURN 'NEW Defining relationships of type SUBJECT_OF_INFORMATION';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_131195008_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_131195008_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:SUBJECT_OF_INFORMATION { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// ACCESS_INSTRUMENT defining relationships
RETURN 'NEW Defining relationships of type ACCESS_INSTRUMENT';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_370127007_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_370127007_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:ACCESS_INSTRUMENT { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// INDIRECT_DEVICE defining relationships
RETURN 'NEW Defining relationships of type INDIRECT_DEVICE';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_363710007_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_363710007_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:INDIRECT_DEVICE { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// RECIPIENT_CATEGORY defining relationships
RETURN 'NEW Defining relationships of type RECIPIENT_CATEGORY';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_370131001_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_370131001_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:RECIPIENT_CATEGORY { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// PATHOLOGICAL_PROCESS defining relationships
RETURN 'NEW Defining relationships of type PATHOLOGICAL_PROCESS';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_370135005_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_370135005_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:PATHOLOGICAL_PROCESS { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// SPECIMEN_SOURCE_TOPOGRAPHY defining relationships
RETURN 'NEW Defining relationships of type SPECIMEN_SOURCE_TOPOGRAPHY';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_118169006_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_118169006_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:SPECIMEN_SOURCE_TOPOGRAPHY { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// SPECIMEN_PROCEDURE defining relationships
RETURN 'NEW Defining relationships of type SPECIMEN_PROCEDURE';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_118171006_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_118171006_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:SPECIMEN_PROCEDURE { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// SPECIMEN_SUBSTANCE defining relationships
RETURN 'NEW Defining relationships of type SPECIMEN_SUBSTANCE';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_370133003_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_370133003_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:SPECIMEN_SUBSTANCE { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// SPECIMEN_SOURCE_IDENTITY defining relationships
RETURN 'NEW Defining relationships of type SPECIMEN_SOURCE_IDENTITY';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_118170007_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_118170007_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:SPECIMEN_SOURCE_IDENTITY { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// SPECIMEN_SOURCE_MORPHOLOGY defining relationships
RETURN 'NEW Defining relationships of type SPECIMEN_SOURCE_MORPHOLOGY';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_118168003_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_118168003_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:SPECIMEN_SOURCE_MORPHOLOGY { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// SCALE_TYPE defining relationships
RETURN 'NEW Defining relationships of type SCALE_TYPE';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_370132008_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_370132008_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:SCALE_TYPE { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// PROPERTY defining relationships
RETURN 'NEW Defining relationships of type PROPERTY';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_370130000_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_370130000_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:PROPERTY { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// TIME_ASPECT defining relationships
RETURN 'NEW Defining relationships of type TIME_ASPECT';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_370134009_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_370134009_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:TIME_ASPECT { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// MEASUREMENT_METHOD defining relationships
RETURN 'NEW Defining relationships of type MEASUREMENT_METHOD';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_370129005_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_370129005_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:MEASUREMENT_METHOD { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// PROCEDURE_SITE__INDIRECT defining relationships
RETURN 'NEW Defining relationships of type PROCEDURE_SITE__INDIRECT';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_405814001_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_405814001_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:PROCEDURE_SITE__INDIRECT { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// AFTER defining relationships
RETURN 'NEW Defining relationships of type AFTER';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_255234002_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_255234002_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:AFTER { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// ASSOCIATED_WITH defining relationships
RETURN 'NEW Defining relationships of type ASSOCIATED_WITH';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_47429007_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_47429007_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:ASSOCIATED_WITH { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// TEMPORAL_CONTEXT defining relationships
RETURN 'NEW Defining relationships of type TEMPORAL_CONTEXT';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_408731000_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_408731000_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:TEMPORAL_CONTEXT { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// FINDING_CONTEXT defining relationships
RETURN 'NEW Defining relationships of type FINDING_CONTEXT';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_408729009_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_408729009_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:FINDING_CONTEXT { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// SUBJECT_RELATIONSHIP_CONTEXT defining relationships
RETURN 'NEW Defining relationships of type SUBJECT_RELATIONSHIP_CONTEXT';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_408732007_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_408732007_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:SUBJECT_RELATIONSHIP_CONTEXT { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// DUE_TO defining relationships
RETURN 'NEW Defining relationships of type DUE_TO';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_42752001_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_42752001_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:DUE_TO { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// PROCEDURE_CONTEXT defining relationships
RETURN 'NEW Defining relationships of type PROCEDURE_CONTEXT';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_408730004_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_408730004_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:PROCEDURE_CONTEXT { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// PROCEDURE_DEVICE defining relationships
RETURN 'NEW Defining relationships of type PROCEDURE_DEVICE';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_405815000_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_405815000_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:PROCEDURE_DEVICE { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// PROCEDURE_SITE__DIRECT defining relationships
RETURN 'NEW Defining relationships of type PROCEDURE_SITE__DIRECT';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_405813007_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_405813007_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:PROCEDURE_SITE__DIRECT { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// PROCEDURE_MORPHOLOGY defining relationships
RETURN 'NEW Defining relationships of type PROCEDURE_MORPHOLOGY';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_405816004_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_405816004_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:PROCEDURE_MORPHOLOGY { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_MANUFACTURED_DOSE_FORM defining relationships
RETURN 'NEW Defining relationships of type HAS_MANUFACTURED_DOSE_FORM';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_411116001_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_411116001_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_MANUFACTURED_DOSE_FORM { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// FINDING_METHOD defining relationships
RETURN 'NEW Defining relationships of type FINDING_METHOD';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_418775008_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_418775008_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:FINDING_METHOD { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// FINDING_INFORMER defining relationships
RETURN 'NEW Defining relationships of type FINDING_INFORMER';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_419066007_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_419066007_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:FINDING_INFORMER { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// ROUTE_OF_ADMINISTRATION defining relationships
RETURN 'NEW Defining relationships of type ROUTE_OF_ADMINISTRATION';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_410675002_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_410675002_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:ROUTE_OF_ADMINISTRATION { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// USING_DEVICE defining relationships
RETURN 'NEW Defining relationships of type USING_DEVICE';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_424226004_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_424226004_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:USING_DEVICE { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// USING_SUBSTANCE defining relationships
RETURN 'NEW Defining relationships of type USING_SUBSTANCE';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_424361007_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_424361007_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:USING_SUBSTANCE { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// CLINICAL_COURSE defining relationships
RETURN 'NEW Defining relationships of type CLINICAL_COURSE';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_263502005_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_263502005_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:CLINICAL_COURSE { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// USING_ENERGY defining relationships
RETURN 'NEW Defining relationships of type USING_ENERGY';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_424244007_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_424244007_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:USING_ENERGY { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// USING_ACCESS_DEVICE defining relationships
RETURN 'NEW Defining relationships of type USING_ACCESS_DEVICE';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_425391005_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_425391005_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:USING_ACCESS_DEVICE { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// SURGICAL_APPROACH defining relationships
RETURN 'NEW Defining relationships of type SURGICAL_APPROACH';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_424876005_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_424876005_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:SURGICAL_APPROACH { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// PROPERTY_TYPE defining relationships
RETURN 'NEW Defining relationships of type PROPERTY_TYPE';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_704318007_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_704318007_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:PROPERTY_TYPE { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// CHARACTERIZES defining relationships
RETURN 'NEW Defining relationships of type CHARACTERIZES';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_704321009_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_704321009_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:CHARACTERIZES { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// PROCESS_OUTPUT defining relationships
RETURN 'NEW Defining relationships of type PROCESS_OUTPUT';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_704324001_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_704324001_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:PROCESS_OUTPUT { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// DIRECT_SITE defining relationships
RETURN 'NEW Defining relationships of type DIRECT_SITE';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_704327008_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_704327008_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:DIRECT_SITE { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// INHERES_IN defining relationships
RETURN 'NEW Defining relationships of type INHERES_IN';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_704319004_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_704319004_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:INHERES_IN { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// PRECONDITION defining relationships
RETURN 'NEW Defining relationships of type PRECONDITION';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_704326004_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_704326004_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:PRECONDITION { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// INHERENT_LOCATION defining relationships
RETURN 'NEW Defining relationships of type INHERENT_LOCATION';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_718497002_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_718497002_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:INHERENT_LOCATION { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// TECHNIQUE defining relationships
RETURN 'NEW Defining relationships of type TECHNIQUE';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_246501002_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_246501002_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:TECHNIQUE { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// RELATIVE_TO_PART_OF defining relationships
RETURN 'NEW Defining relationships of type RELATIVE_TO_PART_OF';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_719715003_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_719715003_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:RELATIVE_TO_PART_OF { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// DURING defining relationships
RETURN 'NEW Defining relationships of type DURING';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_371881003_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_371881003_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:DURING { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_BASIS_OF_STRENGTH_SUBSTANCE defining relationships
RETURN 'NEW Defining relationships of type HAS_BASIS_OF_STRENGTH_SUBSTANCE';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_732943007_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_732943007_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_BASIS_OF_STRENGTH_SUBSTANCE { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_PRESENTATION_STRENGTH_NUMERATOR_VALUE defining relationships
RETURN 'NEW Defining relationships of type HAS_PRESENTATION_STRENGTH_NUMERATOR_VALUE';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_732944001_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_732944001_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_PRESENTATION_STRENGTH_NUMERATOR_VALUE { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_PRESENTATION_STRENGTH_NUMERATOR_UNIT defining relationships
RETURN 'NEW Defining relationships of type HAS_PRESENTATION_STRENGTH_NUMERATOR_UNIT';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_732945000_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_732945000_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_PRESENTATION_STRENGTH_NUMERATOR_UNIT { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_PRESENTATION_STRENGTH_DENOMINATOR_VALUE defining relationships
RETURN 'NEW Defining relationships of type HAS_PRESENTATION_STRENGTH_DENOMINATOR_VALUE';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_732946004_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_732946004_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_PRESENTATION_STRENGTH_DENOMINATOR_VALUE { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_PRESENTATION_STRENGTH_DENOMINATOR_UNIT defining relationships
RETURN 'NEW Defining relationships of type HAS_PRESENTATION_STRENGTH_DENOMINATOR_UNIT';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_732947008_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_732947008_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_PRESENTATION_STRENGTH_DENOMINATOR_UNIT { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_DISPOSITION defining relationships
RETURN 'NEW Defining relationships of type HAS_DISPOSITION';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_726542003_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_726542003_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_DISPOSITION { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_STATE_OF_MATTER defining relationships
RETURN 'NEW Defining relationships of type HAS_STATE_OF_MATTER';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_736518005_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_736518005_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_STATE_OF_MATTER { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_DOSE_FORM_ADMINISTRATION_METHOD defining relationships
RETURN 'NEW Defining relationships of type HAS_DOSE_FORM_ADMINISTRATION_METHOD';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_736472000_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_736472000_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_DOSE_FORM_ADMINISTRATION_METHOD { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_DOSE_FORM_INTENDED_SITE defining relationships
RETURN 'NEW Defining relationships of type HAS_DOSE_FORM_INTENDED_SITE';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_736474004_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_736474004_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_DOSE_FORM_INTENDED_SITE { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_DOSE_FORM_RELEASE_CHARACTERISTIC defining relationships
RETURN 'NEW Defining relationships of type HAS_DOSE_FORM_RELEASE_CHARACTERISTIC';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_736475003_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_736475003_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_DOSE_FORM_RELEASE_CHARACTERISTIC { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_BASIC_DOSE_FORM defining relationships
RETURN 'NEW Defining relationships of type HAS_BASIC_DOSE_FORM';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_736476002_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_736476002_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_BASIC_DOSE_FORM { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_DOSE_FORM_TRANSFORMATION defining relationships
RETURN 'NEW Defining relationships of type HAS_DOSE_FORM_TRANSFORMATION';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_736473005_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_736473005_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_DOSE_FORM_TRANSFORMATION { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// TEMPORALLY_RELATED_TO defining relationships
RETURN 'NEW Defining relationships of type TEMPORALLY_RELATED_TO';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_726633004_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_726633004_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:TEMPORALLY_RELATED_TO { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// IS_MODIFICATION_OF defining relationships
RETURN 'NEW Defining relationships of type IS_MODIFICATION_OF';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_738774007_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_738774007_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:IS_MODIFICATION_OF { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_PRECISE_ACTIVE_INGREDIENT defining relationships
RETURN 'NEW Defining relationships of type HAS_PRECISE_ACTIVE_INGREDIENT';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_762949000_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_762949000_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_PRECISE_ACTIVE_INGREDIENT { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_UNIT_OF_PRESENTATION defining relationships
RETURN 'NEW Defining relationships of type HAS_UNIT_OF_PRESENTATION';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_763032000_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_763032000_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_UNIT_OF_PRESENTATION { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// COUNT_OF_BASE_OF_ACTIVE_INGREDIENT defining relationships
RETURN 'NEW Defining relationships of type COUNT_OF_BASE_OF_ACTIVE_INGREDIENT';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_766952006_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_766952006_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:COUNT_OF_BASE_OF_ACTIVE_INGREDIENT { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_CONCENTRATION_STRENGTH_DENOMINATOR_VALUE defining relationships
RETURN 'NEW Defining relationships of type HAS_CONCENTRATION_STRENGTH_DENOMINATOR_VALUE';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_733723002_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_733723002_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_CONCENTRATION_STRENGTH_DENOMINATOR_VALUE { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_CONCENTRATION_STRENGTH_NUMERATOR_VALUE defining relationships
RETURN 'NEW Defining relationships of type HAS_CONCENTRATION_STRENGTH_NUMERATOR_VALUE';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_733724008_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_733724008_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_CONCENTRATION_STRENGTH_NUMERATOR_VALUE { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_CONCENTRATION_STRENGTH_NUMERATOR_UNIT defining relationships
RETURN 'NEW Defining relationships of type HAS_CONCENTRATION_STRENGTH_NUMERATOR_UNIT';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_733725009_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_733725009_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_CONCENTRATION_STRENGTH_NUMERATOR_UNIT { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_CONCENTRATION_STRENGTH_DENOMINATOR_UNIT defining relationships
RETURN 'NEW Defining relationships of type HAS_CONCENTRATION_STRENGTH_DENOMINATOR_UNIT';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_733722007_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_733722007_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_CONCENTRATION_STRENGTH_DENOMINATOR_UNIT { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// PLAYS_ROLE defining relationships
RETURN 'NEW Defining relationships of type PLAYS_ROLE';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_766939001_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_766939001_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:PLAYS_ROLE { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_REALIZATION defining relationships
RETURN 'NEW Defining relationships of type HAS_REALIZATION';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_719722006_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_719722006_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_REALIZATION { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// PROCESS_DURATION defining relationships
RETURN 'NEW Defining relationships of type PROCESS_DURATION';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_704323007_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_704323007_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:PROCESS_DURATION { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// UNITS defining relationships
RETURN 'NEW Defining relationships of type UNITS';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_246514001_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_246514001_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:UNITS { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_DEVICE_INTENDED_SITE defining relationships
RETURN 'NEW Defining relationships of type HAS_DEVICE_INTENDED_SITE';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_836358009_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_836358009_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_DEVICE_INTENDED_SITE { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_COMPOSITIONAL_MATERIAL defining relationships
RETURN 'NEW Defining relationships of type HAS_COMPOSITIONAL_MATERIAL';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_840560000_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_840560000_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_COMPOSITIONAL_MATERIAL { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_DEVICE_CHARACTERISTIC defining relationships
RETURN 'NEW Defining relationships of type HAS_DEVICE_CHARACTERISTIC';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_840562008_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_840562008_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_DEVICE_CHARACTERISTIC { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_FILLING defining relationships
RETURN 'NEW Defining relationships of type HAS_FILLING';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_827081001_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_827081001_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_FILLING { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_SURFACE_CHARACTERISTIC defining relationships
RETURN 'NEW Defining relationships of type HAS_SURFACE_CHARACTERISTIC';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_246196007_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_246196007_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_SURFACE_CHARACTERISTIC { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// COUNT_OF_ACTIVE_INGREDIENT defining relationships
RETURN 'NEW Defining relationships of type COUNT_OF_ACTIVE_INGREDIENT';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_766953001_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_766953001_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:COUNT_OF_ACTIVE_INGREDIENT { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_PRODUCT_CHARACTERISTIC defining relationships
RETURN 'NEW Defining relationships of type HAS_PRODUCT_CHARACTERISTIC';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_860781008_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_860781008_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_PRODUCT_CHARACTERISTIC { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// RELATIVE_TO defining relationships
RETURN 'NEW Defining relationships of type RELATIVE_TO';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_704325000_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_704325000_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:RELATIVE_TO { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_INGREDIENT_CHARACTERISTIC defining relationships
RETURN 'NEW Defining relationships of type HAS_INGREDIENT_CHARACTERISTIC';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_860779006_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_860779006_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_INGREDIENT_CHARACTERISTIC { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_SURFACE_TEXTURE defining relationships
RETURN 'NEW Defining relationships of type HAS_SURFACE_TEXTURE';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_1148968002_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_1148968002_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_SURFACE_TEXTURE { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_ABSORBABILITY defining relationships
RETURN 'NEW Defining relationships of type HAS_ABSORBABILITY';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_1148969005_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_1148969005_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_ABSORBABILITY { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_COATING_MATERIAL defining relationships
RETURN 'NEW Defining relationships of type HAS_COATING_MATERIAL';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_1148967007_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_1148967007_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_COATING_MATERIAL { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_INGREDIENT_QUALITATIVE_STRENGTH defining relationships
RETURN 'NEW Defining relationships of type HAS_INGREDIENT_QUALITATIVE_STRENGTH';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_1149366004_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_1149366004_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_INGREDIENT_QUALITATIVE_STRENGTH { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// HAS_TARGET_POPULATION defining relationships
RETURN 'NEW Defining relationships of type HAS_TARGET_POPULATION';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_1149367008_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_1149367008_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:HAS_TARGET_POPULATION { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// IS_STERILE defining relationships
RETURN 'NEW Defining relationships of type IS_STERILE';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_1148965004_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_1148965004_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:IS_STERILE { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// PROCESS_EXTENDS_TO defining relationships
RETURN 'NEW Defining relationships of type PROCESS_EXTENDS_TO';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_1003703000_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_1003703000_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:PROCESS_EXTENDS_TO { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// BEFORE defining relationships
RETURN 'NEW Defining relationships of type BEFORE';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_288556008_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_288556008_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:BEFORE { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// PROCESS_ACTS_ON defining relationships
RETURN 'NEW Defining relationships of type PROCESS_ACTS_ON';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_1003735000_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_1003735000_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:PROCESS_ACTS_ON { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// TOWARDS defining relationships
RETURN 'NEW Defining relationships of type TOWARDS';

LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_704320005_new.csv" as line
CALL {
  with line 
  MERGE (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
 } IN TRANSACTIONS OF 200 ROWS;

// Add defining relationship edge in 2nd step, Java memory issue
LOAD CSV with headers from "file:/var/lib/neo4j/import/DR_704320005_new.csv" as line
CALL {
  with line 
  MATCH (rg:RoleGroup { sctid: line.sctid, rolegroup: line.rolegroup })
WITH line,rg 
  MATCH (c:ObjectConcept { sctid: line.destinationId })
  MERGE (rg)-[:TOWARDS { id: line.id, active: line.active, sctid: line.sctid,
                               typeId: line.typeId,
                               rolegroup: line.rolegroup, effectiveTime: line.effectiveTime,
                               moduleId: line.moduleId, characteristicTypeId: line.characteristicTypeId,
                               modifierId: line.modifierId,
                               history: line.history }]->(c)
 } IN TRANSACTIONS OF 200 ROWS;
// Finito
