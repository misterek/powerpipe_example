
This is an eample dashboard for PowerPipe to demonstrate some struggles. It's not super great.


# Goal 

Create a dashboard to show, for each AWS IAM Identity Center Group, what accounts the group grants access to, and what permissions within those accounts are granted.

## Context

AWS IAM Identity Center is.. odd sometimes.

There are three thigns goign on:
* AWS Accounts
* Groups (or users, but I don't need those now)
* Permission Sets

Giving access is a combination of these.  A Group has access to 1 or more combinations of (Account + Permissions)


## Problems

Steampipe is great to get information, but does have to make some concessions given the restrictions of the API.

In this case, the big problem is that the "aws_ssoadmin_account_assignment" table requires you to pass both permission_set_arn and target_account_id. (https://github.com/turbot/steampipe-plugin-aws/issues/1668)

So you can't just say "give me all account assignments".  Which makes it tricky.

So, first problem is solving this. After trying a lot of ways, the best I ended up with was a function that tries _all_ possible combinations.  This ends up in a ton of API calls, since it's permission sets * accounts.

That was problem number 1.


Problem number 2 -- I may be missing something, but it appears all of the inline sql and queries use prepared statements. So, i couldn't both create and use the function in the same block.

My (terrible) solution is to have a fake input box that just creates the function.  This works, but is clearly not great.



## Conclusion
This works, but it's slow and awkward.  The information provided is very helpful, but for an organization that had hundreds of accounts and dozens of permission sets, it's not going to scale well.

Also, for some reason, the caching doesn't seem to be working like I expected. I set it for an hour, but it doesn't always seem to work.

Also, note that I put no effort into formatting or anything. This was simply a POC.