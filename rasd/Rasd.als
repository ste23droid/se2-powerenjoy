open util/boolean


//SIGNATURES

sig Name, Surname, Addr{}
sig Email, Password, PIN{}
sig PaymentMethod{}

abstract sig User {
	name: some Name,
	surname: some Surname,
	address: one Addr,
	email: one Email,
    password: one Password,
}

sig RegisteredUser extends User{
	pin: one PIN,
	suspended: one Bool,
	paymentMethod: one PaymentMethod,
	reservations: set Reservation
}

sig Operator extends User {
	carUnderMaintenance : lone Car
}

//A reservation is considered active from its creation until its termination
sig Reservation {
	creator : one RegisteredUser,
	reservedCar: one Car,
	requestUnlock: some UnlockRequest, //user can make different car's unlock requests during his reservation
	active: one Bool
	}

sig GPS{}

sig UnlockRequest {
correctUserPosition: one Bool, 
unlockOutcome: one Bool //the request can have a positive or negative outcome
}

sig Car{
	position: one GPS,
	available: one Bool,
	inMaintenance: one Bool,
	reserved: one Bool,
	reservation : set Reservation,
	locked: one Bool,
	inCharge: one Bool
}

sig SafeArea {
	coordinates: one GPS,
	numberOfSpots: one Int,
	availableSpots: one Int,
	powerGrid: one Bool
}{
	numberOfSpots > 0
	availableSpots >= 0
}


//FACTS

//Two different users can’t have the same email
fact NoSameEmailForDifferentUsers {
	no disjoint u1, u2 : User | u1.email = u2.email
}

//Two different registered users can’t have the same PIN
fact NoSamePINForDifferentUsers {
	no disjoint u1, u2 : RegisteredUser | u1.pin = u2.pin
}

//If a car is under maintenance, one and at most one operator is taking care of it
fact carUnderMaintenanceByOperator {
	all c: Car | one o: Operator | (c.inMaintenance = True implies o.carUnderMaintenance = c)
}

fact carAndOperatorRelation {
	all c: Car | all o: Operator | o.carUnderMaintenance = c implies c.inMaintenance = True
}

//If a car is available or in maintenance no active reservations are associated to it
fact carAvailableOrInMaintenance{
	all c: Car | (c.available = True or c.inMaintenance = True) iff #getActiveCarReservation[c] = 0
}

//A Car can't be in maintenance and available
fact carMaintenance {
	no c: Car | c.inMaintenance = True and c.available = True
}

//If a car is reserved, one active reservation is associated to it
fact carReserved {
	all c: Car | c.reserved = True iff #getActiveCarReservation[c] = 1 
}

//If a Reservation instance is related to a User entity, then it is also related to the corresponding Car entity 
fact ReservationUserAndCar {
	all r: Reservation | all u: RegisteredUser | all c: Car |  ( (r in u.reservations) and c = r.reservedCar)
	implies (r in c.reservation)
}

//A Car entity is associated with only the Reservation entities on that car
fact CarReservation {
	all c: Car | all r: Reservation | r in c.reservation implies r.reservedCar = c  
}

//A User entity is associated with only the Reservation entities created by that User
fact UserReservation {
	all r: Reservation | all u: RegisteredUser | r in u.reservations implies r.creator = u
}

//No contemporary reservations on the same car are allowed
fact NoMultipleActiveReservationOnSameCar {
	all c: Car | #getActiveCarReservation[c] <= 1
}

//No contemporary reservations of the same user are allowed
fact NoMultipleActiveReservationForSameUser{
	all u: RegisteredUser | #getActiveUserReservation[u] <= 1
}

//If a user is suspended, none of his reservation is active
fact userSuspended {
	all u: RegisteredUser | all r: Reservation | (u. suspended = True and r in u.reservations) implies
	r.active = False
}

//The unlock request is successful only when the user is close enough to the car and vice versa
fact unlockRequestOutcome {
	all u: UnlockRequest | u.unlockOutcome = True iff u.correctUserPosition = True
}

//Each Reservation has a unique set of UnlockRequest
fact unlockRequestAndReservation {
	all disjoint r1, r2 : Reservation | r1.requestUnlock & r2.requestUnlock = none
}

//The available spots of a safe area are calculated as the total number of spots minus the cars in that safe area
fact totalAvailableSpots  {
	all a: SafeArea | a.availableSpots <= a.numberOfSpots 
	and a.availableSpots = minus[a.numberOfSpots, #getTotalCarInSafeArea[a]]
}

//When a car is available, it is locked and situated in a safe area
fact availableCarPosition {
	all c : Car | one a: SafeArea | c.available = True implies (c.locked = True and
	c.position = a.coordinates)
}

//Safe areas are located at different locations
fact safeAreasDifferentLocation {
all disjoint a1, a2 : SafeArea | a1.coordinates != a2.coordinates
}

//---FUNCTIONS---

//Return all the active reservations of a user
fun getActiveUserReservation[u: RegisteredUser] : set Reservation {
	{r: Reservation | r.creator = u and r.active = True }
}

//Return all the active reservation associated to a car
fun getActiveCarReservation[c: Car] : set Reservation {
	{r: Reservation | r.reservedCar = c and r.active = True }
}

//Return all the cars located in a safe area
fun getTotalCarInSafeArea[a: SafeArea] : set Car {
	{c: Car | c.position = a.coordinates}
}

// ---ASSERTS---

//Check if the car can only be in one status at a time
assert carStatusConsistency {
	no c: Car | (c.reserved = True and c.available = True) or 
					(c.inMaintenance = True  and c.available = True ) or
					(c.reserved = True and c.inMaintenance = True ) or
					(c.reserved = False and c.inMaintenance = False and c.available = False)
}

check carStatusConsistency

//Check the interaction between cars and reservations
assert ReservationConsistency {
	all c: Car | all r: Reservation | (#getActiveCarReservation[c] = 0 and r.reservedCar = c)
 	implies r.active = False 
}

check ReservationConsistency

//Check if a Reservation entity is correctly related between User and Car
assert ReservationOfAvailableCars {
all u: RegisteredUser | all r: Reservation | (r.active = True and r in u.reservations) implies 
( r.reservedCar.reserved = True and r in r.reservedCar.reservation)
}

check ReservationOfAvailableCars 

pred show() {
#Name > 1
#Addr > 1 //imposed for clarity porpouse, but users with same name or surname are admitted
}

run show for 2
